ALTER TABLE subscriptions DROP CONSTRAINT subscriptions_status_check;
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_status_check CHECK(status IN ('pending','active','trialing','past_due','cancelled','halted'));
ALTER TABLE subscriptions ADD COLUMN grace_ends_at TIMESTAMPTZ;
ALTER TABLE subscriptions ADD COLUMN last_event_at TIMESTAMPTZ;
ALTER TABLE subscriptions ADD COLUMN checkout_url TEXT;
ALTER TABLE subscriptions ADD COLUMN billing_cycle TEXT NOT NULL DEFAULT 'monthly' CHECK(billing_cycle IN ('monthly','yearly'));
ALTER TABLE subscriptions ADD COLUMN pending_plan TEXT CHECK(pending_plan IN ('basic','standard','pro'));
CREATE UNIQUE INDEX invoices_saas_payment_unique ON invoices_saas(razorpay_payment_id) WHERE razorpay_payment_id IS NOT NULL;
CREATE UNIQUE INDEX one_pending_checkout_per_tenant ON subscriptions(tenant_id) WHERE status='pending';
CREATE TABLE provider_events (
  provider TEXT NOT NULL, event_id TEXT NOT NULL, event_type TEXT NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(), PRIMARY KEY(provider,event_id)
);
ALTER TABLE provider_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION apply_razorpay_event(p_event_id TEXT,p_event JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_sub subscriptions; v_remote JSONB := p_event->'payload'->'subscription'->'entity';
  v_payment JSONB := p_event->'payload'->'payment'->'entity'; v_kind TEXT := p_event->>'event';
  v_status TEXT; v_at TIMESTAMPTZ := to_timestamp((p_event->>'created_at')::bigint);
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  IF EXISTS(SELECT 1 FROM provider_events WHERE provider='razorpay' AND event_id=p_event_id) THEN RETURN '{"duplicate":true}'::jsonb; END IF;
  SELECT * INTO v_sub FROM subscriptions WHERE razorpay_sub_id=v_remote->>'id' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Subscription is not registered yet; retry delivery'; END IF;
  INSERT INTO provider_events(provider,event_id,event_type) VALUES('razorpay',p_event_id,v_kind) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RETURN '{"duplicate":true}'::jsonb; END IF;
  IF v_kind='subscription.charged' AND v_payment->>'id' IS NOT NULL THEN
    INSERT INTO invoices_saas(tenant_id,subscription_id,amount_paise,status,razorpay_payment_id,paid_at)
    VALUES(v_sub.tenant_id,v_sub.id,(v_payment->>'amount')::int,'paid',v_payment->>'id',COALESCE(v_at,now()))
    ON CONFLICT(razorpay_payment_id) WHERE razorpay_payment_id IS NOT NULL DO NOTHING;
  END IF;
  IF v_sub.last_event_at IS NOT NULL AND v_at < v_sub.last_event_at THEN RETURN '{"stale":true}'::jsonb; END IF;
  v_status := CASE v_kind WHEN 'subscription.charged' THEN 'active' WHEN 'subscription.activated' THEN 'active'
    WHEN 'subscription.resumed' THEN 'active' WHEN 'subscription.halted' THEN 'halted' WHEN 'subscription.paused' THEN 'halted'
    WHEN 'subscription.cancelled' THEN 'cancelled' WHEN 'subscription.completed' THEN 'cancelled' ELSE NULL END;
  IF v_status IS NOT NULL THEN
    UPDATE subscriptions SET status=v_status,last_event_at=COALESCE(v_at,now()),
      current_period_start=COALESCE(to_timestamp((v_remote->>'current_start')::bigint),current_period_start),
      current_period_end=COALESCE(to_timestamp((v_remote->>'current_end')::bigint),current_period_end),
      grace_ends_at=CASE WHEN v_status='halted' THEN COALESCE(v_at,now())+interval '3 days' ELSE NULL END,
      cancelled_at=CASE WHEN v_status='cancelled' THEN COALESCE(v_at,now()) ELSE NULL END
    WHERE id=v_sub.id;
    IF v_status='active' THEN UPDATE tenants SET plan=v_sub.plan WHERE id=v_sub.tenant_id; END IF;
    IF v_status='cancelled' AND COALESCE(to_timestamp((v_remote->>'current_end')::bigint),v_sub.current_period_end,now()) <= now() THEN
      UPDATE tenants SET plan='free' WHERE id=v_sub.tenant_id
      AND NOT EXISTS(SELECT 1 FROM subscriptions WHERE tenant_id=v_sub.tenant_id AND id<>v_sub.id AND status='active');
    END IF;
    INSERT INTO audit_log(tenant_id,action,entity,record_id,metadata)
    VALUES(v_sub.tenant_id,v_kind,'subscription',v_sub.id,jsonb_build_object('event_id',p_event_id));
  END IF;
  RETURN '{"received":true}'::jsonb;
END;
$$;

CREATE OR REPLACE FUNCTION expire_subscription_access()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_count INT;
BEGIN
  IF auth.role() <> 'service_role' THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  UPDATE tenants t SET plan='free' WHERE t.plan<>'free'
    AND EXISTS(SELECT 1 FROM subscriptions s WHERE s.tenant_id=t.id AND
      ((s.status IN ('halted','past_due') AND s.grace_ends_at <= now()) OR (s.status='cancelled' AND COALESCE(s.current_period_end,s.cancelled_at)<=now())))
    AND NOT EXISTS(SELECT 1 FROM subscriptions s WHERE s.tenant_id=t.id AND s.status='active');
  GET DIAGNOSTICS v_count = ROW_COUNT;
  UPDATE subscriptions SET status='cancelled',cancelled_at=now() WHERE status='trialing' AND current_period_end<=now();
  RETURN v_count;
END;
$$;

ALTER TABLE whatsapp_logs DROP CONSTRAINT whatsapp_logs_status_check;
ALTER TABLE whatsapp_logs ADD CONSTRAINT whatsapp_logs_status_check CHECK(status IN ('queued','sent','delivered','read','failed'));
ALTER TABLE whatsapp_logs ADD COLUMN dedup_key TEXT;
CREATE UNIQUE INDEX whatsapp_dedup ON whatsapp_logs(tenant_id,dedup_key) WHERE dedup_key IS NOT NULL;
CREATE INDEX whatsapp_provider_id ON whatsapp_logs(provider_message_id) WHERE provider_message_id IS NOT NULL;

CREATE OR REPLACE FUNCTION reserve_whatsapp(p_tenant UUID,p_recipient TEXT,p_template TEXT,p_dedup TEXT DEFAULT NULL,p_system BOOLEAN DEFAULT false)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_plan TEXT; v_limit INT; v_id UUID;
BEGIN
  IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,1));
  IF p_dedup IS NOT NULL THEN SELECT id INTO v_id FROM whatsapp_logs WHERE tenant_id=p_tenant AND dedup_key=p_dedup; IF FOUND THEN RETURN NULL; END IF; END IF;
  SELECT plan INTO v_plan FROM tenants WHERE id=p_tenant AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shop not active'; END IF;
  v_limit := CASE WHEN p_system AND p_template='trial_ending' THEN 3 WHEN v_plan='standard' THEN 500 WHEN v_plan='pro' THEN 2000 ELSE 0 END;
  IF v_limit=0 THEN RAISE EXCEPTION 'WhatsApp requires Standard or Pro'; END IF;
  IF (SELECT count(*) FROM whatsapp_logs WHERE tenant_id=p_tenant AND created_at>=date_trunc('month',now())
    AND (NOT p_system OR template=p_template))>=v_limit THEN RAISE EXCEPTION 'Monthly WhatsApp quota reached'; END IF;
  INSERT INTO whatsapp_logs(tenant_id,recipient,template,status,dedup_key) VALUES(p_tenant,p_recipient,p_template,'queued',p_dedup) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE TABLE workflow_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
  event TEXT NOT NULL, record JSONB NOT NULL, status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','running','completed','failed')),
  attempts INT NOT NULL DEFAULT 0, error TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), locked_at TIMESTAMPTZ
);
ALTER TABLE workflow_jobs ENABLE ROW LEVEL SECURITY;
CREATE INDEX workflow_jobs_pending ON workflow_jobs(created_at) WHERE status='pending';
CREATE OR REPLACE FUNCTION enqueue_record_workflows()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_event TEXT; v_entity entities;
BEGIN
  v_event := CASE WHEN TG_OP='INSERT' THEN 'record.created' WHEN NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN 'record.deleted' ELSE 'record.updated' END;
  SELECT * INTO v_entity FROM entities WHERE id=NEW.entity_id;
  INSERT INTO workflow_jobs(tenant_id,workflow_id,event,record)
  SELECT NEW.tenant_id,w.id,v_event,NEW.data || jsonb_build_object('id',NEW.id) FROM workflows w
  WHERE w.app_id=v_entity.app_id AND w.is_active AND w.trigger->>'type'=v_event AND w.trigger->>'entity'=v_entity.name;
  RETURN NEW;
END;
$$;
CREATE TRIGGER record_workflows AFTER INSERT OR UPDATE ON records FOR EACH ROW EXECUTE FUNCTION enqueue_record_workflows();

CREATE OR REPLACE FUNCTION claim_workflow_jobs(p_limit INT DEFAULT 25)
RETURNS SETOF workflow_jobs LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF auth.role()<>'service_role' THEN RAISE EXCEPTION 'Forbidden' USING ERRCODE='42501'; END IF;
  RETURN QUERY UPDATE workflow_jobs SET status='running',locked_at=now(),attempts=attempts+1
  WHERE id IN (SELECT id FROM workflow_jobs WHERE status='pending' ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT LEAST(p_limit,100)) RETURNING *;
END;
$$;
REVOKE ALL ON FUNCTION apply_razorpay_event(TEXT,JSONB),expire_subscription_access(),reserve_whatsapp(UUID,TEXT,TEXT,TEXT,BOOLEAN),claim_workflow_jobs(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION apply_razorpay_event(TEXT,JSONB),expire_subscription_access(),reserve_whatsapp(UUID,TEXT,TEXT,TEXT,BOOLEAN),claim_workflow_jobs(INT) TO service_role;
