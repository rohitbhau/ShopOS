-- Trusted tenant selection, transactional onboarding and role-aware isolation.
ALTER TABLE profiles ALTER COLUMN phone DROP NOT NULL;
ALTER TABLE tenants ADD COLUMN settings JSONB NOT NULL DEFAULT '{}';
ALTER TABLE apps ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE apps ADD COLUMN published_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.provision_profile()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles(id, phone, name)
  VALUES (NEW.id, NULLIF(NEW.phone, ''), COALESCE(NEW.raw_user_meta_data->>'name', ''))
  ON CONFLICT (id) DO UPDATE SET phone = EXCLUDED.phone;
  RETURN NEW;
END;
$$;
CREATE TRIGGER auth_user_profile AFTER INSERT OR UPDATE OF phone ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.provision_profile();
INSERT INTO profiles(id, phone, name)
SELECT id, NULLIF(phone, ''), COALESCE(raw_user_meta_data->>'name', '') FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- Security-definer avoids recursive membership RLS; the membership is rechecked
-- on every statement, so revocation works even for an unexpired access token.
CREATE OR REPLACE FUNCTION auth.tenant_id()
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.tenant_id FROM memberships m JOIN tenants t ON t.id = m.tenant_id
  WHERE m.user_id = auth.uid() AND m.is_active AND t.is_active
    AND m.tenant_id::text = auth.jwt()->'app_metadata'->>'tenant_id'
  LIMIT 1;
$$;
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT role FROM memberships
    WHERE tenant_id = auth.tenant_id() AND user_id = auth.uid() AND is_active), 'viewer');
$$;

-- Remove the original broad write policies before adding restrictive policies.
DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public'
    AND tablename IN ('tenants','profiles','memberships','apps','entities','records','workflows',
      'workflow_executions','subscriptions','invoices_saas','payment_methods','audit_log',
      'feature_flags','feature_overrides','whatsapp_logs')
  LOOP EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, p.tablename); END LOOP;
END $$;

CREATE POLICY tenant_read ON tenants FOR SELECT TO authenticated USING (id = auth.tenant_id());
CREATE POLICY tenant_update ON tenants FOR UPDATE TO authenticated
USING (id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'))
WITH CHECK (id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'));
-- Prevent owners from writing subscription entitlements through tenant settings.
REVOKE UPDATE ON tenants FROM authenticated;
GRANT UPDATE(name, phone, address, gstin, logo_url, settings) ON tenants TO authenticated;
CREATE POLICY profile_read ON profiles FOR SELECT TO authenticated USING
(id = auth.uid() OR id IN (SELECT user_id FROM memberships WHERE tenant_id = auth.tenant_id()));
CREATE POLICY profile_update ON profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY membership_read ON memberships FOR SELECT TO authenticated USING
(user_id = auth.uid() OR tenant_id = auth.tenant_id());
-- Membership changes go through manage_staff, protecting the last owner.
CREATE POLICY apps_read ON apps FOR SELECT TO authenticated USING (tenant_id = auth.tenant_id());
CREATE POLICY apps_manage ON apps FOR ALL TO authenticated
USING (tenant_id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'))
WITH CHECK (tenant_id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'));
CREATE POLICY entities_read ON entities FOR SELECT TO authenticated
USING (app_id IN (SELECT id FROM apps WHERE tenant_id = auth.tenant_id()));
CREATE POLICY entities_manage ON entities FOR ALL TO authenticated
USING (app_id IN (SELECT id FROM apps WHERE tenant_id = auth.tenant_id()) AND auth.user_role() IN ('owner','manager'))
WITH CHECK (app_id IN (SELECT id FROM apps WHERE tenant_id = auth.tenant_id()) AND auth.user_role() IN ('owner','manager'));
CREATE POLICY records_read ON records FOR SELECT TO authenticated USING
(tenant_id = auth.tenant_id() AND entity_id IN
 (SELECT e.id FROM entities e JOIN apps a ON a.id = e.app_id WHERE a.tenant_id = auth.tenant_id()));
-- All record writes use sync_mutations for validation, stock arithmetic and receipts.
CREATE POLICY workflows_read ON workflows FOR SELECT TO authenticated
USING (app_id IN (SELECT id FROM apps WHERE tenant_id = auth.tenant_id()) AND auth.user_role() IN ('owner','manager'));
CREATE POLICY workflows_manage ON workflows FOR ALL TO authenticated
USING (app_id IN (SELECT id FROM apps WHERE tenant_id = auth.tenant_id()) AND auth.user_role() IN ('owner','manager'))
WITH CHECK (app_id IN (SELECT id FROM apps WHERE tenant_id = auth.tenant_id()) AND auth.user_role() IN ('owner','manager'));
CREATE POLICY executions_read ON workflow_executions FOR SELECT TO authenticated
USING (tenant_id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'));
CREATE POLICY subscriptions_read ON subscriptions FOR SELECT TO authenticated
USING (tenant_id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'));
CREATE POLICY saas_invoices_read ON invoices_saas FOR SELECT TO authenticated
USING (tenant_id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'));
CREATE POLICY payment_methods_read ON payment_methods FOR SELECT TO authenticated
USING (tenant_id = auth.tenant_id() AND auth.user_role() = 'owner');
CREATE POLICY audit_read ON audit_log FOR SELECT TO authenticated
USING (tenant_id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'));
CREATE POLICY flags_read ON feature_flags FOR SELECT TO authenticated USING (true);
CREATE POLICY overrides_read ON feature_overrides FOR SELECT TO authenticated USING (tenant_id = auth.tenant_id());
CREATE POLICY whatsapp_read ON whatsapp_logs FOR SELECT TO authenticated
USING (tenant_id = auth.tenant_id() AND auth.user_role() IN ('owner','manager'));

CREATE TABLE shop_templates (
  key TEXT PRIMARY KEY, name TEXT NOT NULL, entities JSONB NOT NULL,
  workflows JSONB NOT NULL DEFAULT '[]', dashboard JSONB NOT NULL DEFAULT '{}'
);
ALTER TABLE shop_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY templates_read ON shop_templates FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION seed_shop_template(p_app_id UUID, p_template_key TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tenant UUID; v_template shop_templates; v_entity JSONB; v_workflow JSONB; v_order INT := 0;
BEGIN
  SELECT tenant_id INTO v_tenant FROM apps WHERE id = p_app_id FOR UPDATE;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'App not found'; END IF;
  IF auth.role() <> 'service_role' AND (v_tenant IS DISTINCT FROM auth.tenant_id() OR auth.user_role() NOT IN ('owner','manager')) THEN
    RAISE EXCEPTION 'Forbidden' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_template FROM shop_templates WHERE key = p_template_key;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown template'; END IF;
  FOR v_entity IN SELECT value FROM jsonb_array_elements(v_template.entities) LOOP
    INSERT INTO entities(app_id,name,label,icon,schema,is_system,display_order)
    VALUES(p_app_id,v_entity->>'name',v_entity->>'label',COALESCE(v_entity->>'icon','file'),v_entity->'schema',
      COALESCE((v_entity->>'is_system')::boolean,false),v_order)
    ON CONFLICT(app_id,name) DO NOTHING;
    v_order := v_order + 1;
  END LOOP;
  FOR v_workflow IN SELECT value FROM jsonb_array_elements(v_template.workflows) LOOP
    IF NOT EXISTS(SELECT 1 FROM workflows WHERE app_id = p_app_id AND name = v_workflow->>'name') THEN
      INSERT INTO workflows(app_id,name,trigger,conditions,actions,is_active)
      VALUES(p_app_id,v_workflow->>'name',v_workflow->'trigger',v_workflow->'conditions',v_workflow->'actions',true);
    END IF;
  END LOOP;
  UPDATE apps SET template_key = p_template_key, config = config || jsonb_build_object('dashboard',v_template.dashboard),
    schema_version = schema_version + 1, published_at = now() WHERE id = p_app_id;
  RETURN jsonb_build_object('success',true,'template_key',p_template_key);
END;
$$;

CREATE TABLE onboarding_requests (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE
);
ALTER TABLE onboarding_requests ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION create_shop(p_name TEXT, p_shop_type TEXT, p_template_key TEXT,
  p_phone TEXT DEFAULT NULL, p_address JSONB DEFAULT '{}', p_gstin TEXT DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user UUID := auth.uid(); v_tenant tenants; v_app apps; v_existing UUID;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501'; END IF;
  IF length(trim(p_name)) NOT BETWEEN 2 AND 100 THEN RAISE EXCEPTION 'Shop name must contain 2 to 100 characters'; END IF;
  IF NOT EXISTS(SELECT 1 FROM shop_templates WHERE key = p_template_key) THEN RAISE EXCEPTION 'Unknown template'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
  SELECT tenant_id INTO v_existing FROM onboarding_requests WHERE user_id = v_user;
  IF v_existing IS NOT NULL THEN
    SELECT * INTO v_tenant FROM tenants WHERE id = v_existing;
    SELECT * INTO v_app FROM apps WHERE tenant_id = v_existing ORDER BY created_at LIMIT 1;
    RETURN jsonb_build_object('success',true,'tenant',to_jsonb(v_tenant),'app',to_jsonb(v_app));
  END IF;
  IF EXISTS(SELECT 1 FROM memberships WHERE user_id = v_user AND is_active AND role = 'owner') THEN
    RAISE EXCEPTION 'Select your existing shop before creating another shop';
  END IF;
  INSERT INTO profiles(id,phone) SELECT id,NULLIF(phone,'') FROM auth.users WHERE id = v_user ON CONFLICT(id) DO NOTHING;
  INSERT INTO tenants(name,shop_type,phone,address,gstin)
  VALUES(trim(p_name),p_shop_type,p_phone,COALESCE(p_address,'{}'),NULLIF(p_gstin,'')) RETURNING * INTO v_tenant;
  INSERT INTO memberships(tenant_id,user_id,role) VALUES(v_tenant.id,v_user,'owner');
  INSERT INTO apps(tenant_id,name,template_key) VALUES(v_tenant.id,'Main App',p_template_key) RETURNING * INTO v_app;
  -- Seed inside the same database transaction; rollback includes all entities.
  INSERT INTO entities(app_id,name,label,icon,schema,is_system,display_order)
  SELECT v_app.id,e->>'name',e->>'label',COALESCE(e->>'icon','file'),e->'schema',
    COALESCE((e->>'is_system')::boolean,false),ordinality::int
  FROM shop_templates t, jsonb_array_elements(t.entities) WITH ORDINALITY AS value(e,ordinality) WHERE t.key = p_template_key;
  INSERT INTO workflows(app_id,name,trigger,conditions,actions)
  SELECT v_app.id,w->>'name',w->'trigger',w->'conditions',w->'actions'
  FROM shop_templates t, jsonb_array_elements(t.workflows) AS value(w) WHERE t.key = p_template_key;
  UPDATE apps SET config = jsonb_build_object('dashboard',(SELECT dashboard FROM shop_templates WHERE key = p_template_key)),
    published_at = now() WHERE id = v_app.id;
  INSERT INTO subscriptions(tenant_id,plan,status,current_period_end) VALUES(v_tenant.id,'free','trialing',v_tenant.trial_ends_at);
  INSERT INTO onboarding_requests(user_id,tenant_id) VALUES(v_user,v_tenant.id);
  INSERT INTO audit_log(tenant_id,user_id,action,entity,record_id) VALUES(v_tenant.id,v_user,'tenant.created','tenant',v_tenant.id);
  RETURN jsonb_build_object('success',true,'tenant',to_jsonb(v_tenant),'app',to_jsonb(v_app));
END;
$$;

CREATE OR REPLACE FUNCTION manage_staff(p_user_id UUID, p_role TEXT DEFAULT 'cashier', p_active BOOLEAN DEFAULT true)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tenant UUID := auth.tenant_id(); v_id UUID; v_plan TEXT; v_limit INT;
BEGIN
  IF v_tenant IS NULL OR auth.user_role() <> 'owner' THEN RAISE EXCEPTION 'Only an owner can manage staff' USING ERRCODE = '42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_tenant::text,0));
  IF p_role NOT IN ('owner','manager','cashier','viewer') THEN RAISE EXCEPTION 'Invalid role'; END IF;
  IF p_user_id = auth.uid() AND (p_role <> 'owner' OR NOT p_active) THEN RAISE EXCEPTION 'You cannot remove your own owner access'; END IF;
  SELECT plan INTO v_plan FROM tenants WHERE id = v_tenant;
  v_limit := CASE v_plan WHEN 'free' THEN 1 WHEN 'basic' THEN 3 WHEN 'standard' THEN 10 ELSE 100 END;
  IF p_active AND NOT EXISTS(SELECT 1 FROM memberships WHERE tenant_id = v_tenant AND user_id = p_user_id AND is_active)
    AND (SELECT count(*) FROM memberships WHERE tenant_id = v_tenant AND is_active) >= v_limit THEN RAISE EXCEPTION 'Staff limit reached for this plan'; END IF;
  INSERT INTO memberships(tenant_id,user_id,role,is_active) VALUES(v_tenant,p_user_id,p_role,p_active)
  ON CONFLICT(tenant_id,user_id) DO UPDATE SET role = EXCLUDED.role,is_active = EXCLUDED.is_active RETURNING id INTO v_id;
  INSERT INTO audit_log(tenant_id,user_id,action,entity,record_id,diff)
  VALUES(v_tenant,auth.uid(),'staff.updated','membership',v_id,jsonb_build_object('role',p_role,'is_active',p_active));
  RETURN jsonb_build_object('id',v_id);
END;
$$;

REVOKE ALL ON FUNCTION provision_profile() FROM PUBLIC;
REVOKE ALL ON FUNCTION seed_shop_template(UUID,TEXT), create_shop(TEXT,TEXT,TEXT,TEXT,JSONB,TEXT), manage_staff(UUID,TEXT,BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION create_shop(TEXT,TEXT,TEXT,TEXT,JSONB,TEXT), manage_staff(UUID,TEXT,BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION seed_shop_template(UUID,TEXT) TO authenticated, service_role;
