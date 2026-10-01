CREATE TABLE sync_receipts (
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  mutation_id UUID NOT NULL, user_id UUID NOT NULL REFERENCES auth.users(id),
  mutation JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(tenant_id,mutation_id)
);
ALTER TABLE sync_receipts ENABLE ROW LEVEL SECURITY;
CREATE INDEX records_sync_cursor ON records(tenant_id,updated_at,id);
CREATE UNIQUE INDEX records_invoice_number ON records(tenant_id,entity_id,(data->>'invoice_number'))
WHERE data->>'invoice_number' IS NOT NULL AND deleted_at IS NULL;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at = clock_timestamp(); RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION enforce_record_tenant()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM entities e JOIN apps a ON a.id=e.app_id WHERE e.id=NEW.entity_id AND a.tenant_id=NEW.tenant_id) THEN
    RAISE EXCEPTION 'Record entity belongs to another shop' USING ERRCODE='23514';
  END IF;
  IF TG_OP = 'UPDATE' AND (NEW.tenant_id <> OLD.tenant_id OR NEW.entity_id <> OLD.entity_id OR NEW.id <> OLD.id) THEN
    RAISE EXCEPTION 'Record identity is immutable';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER record_tenant_guard BEFORE INSERT OR UPDATE ON records FOR EACH ROW EXECUTE FUNCTION enforce_record_tenant();

CREATE OR REPLACE FUNCTION merge_json_objects(p_old JSONB, p_new JSONB)
RETURNS JSONB LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE v_result JSONB := p_old; v_key TEXT; v_value JSONB;
BEGIN
  IF jsonb_typeof(p_old) <> 'object' OR jsonb_typeof(p_new) <> 'object' THEN RETURN p_new; END IF;
  FOR v_key,v_value IN SELECT key,value FROM jsonb_each(p_new) LOOP
    v_result := jsonb_set(v_result,ARRAY[v_key],CASE WHEN jsonb_typeof(v_value)='object' AND jsonb_typeof(v_result->v_key)='object'
      THEN merge_json_objects(v_result->v_key,v_value) ELSE v_value END,true);
  END LOOP;
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION validate_record_data(p_schema JSONB,p_data JSONB)
RETURNS VOID LANGUAGE plpgsql SET search_path = public AS $$
DECLARE f JSONB; v JSONB; n TEXT; t TEXT;
BEGIN
  IF jsonb_typeof(p_data) <> 'object' THEN RAISE EXCEPTION 'Record data must be an object'; END IF;
  FOR f IN SELECT value FROM jsonb_array_elements(COALESCE(p_schema->'fields','[]')) LOOP
    n := f->>'name'; t := f->>'type'; v := p_data->n;
    IF COALESCE((f->>'required')::boolean,false) AND (v IS NULL OR v='null'::jsonb OR v='""'::jsonb) THEN
      RAISE EXCEPTION 'Missing required field: %',n;
    END IF;
    IF v IS NULL OR v='null'::jsonb THEN CONTINUE; END IF;
    IF t IN ('number','decimal') THEN
      IF jsonb_typeof(v) <> 'number' THEN RAISE EXCEPTION 'Invalid numeric field: %',n; END IF;
      IF f ? 'min' AND (v::text)::numeric < (f->>'min')::numeric THEN RAISE EXCEPTION 'Below minimum: %',n; END IF;
      IF f ? 'max' AND (v::text)::numeric > (f->>'max')::numeric THEN RAISE EXCEPTION 'Above maximum: %',n; END IF;
    ELSIF t IN ('bool','boolean') AND jsonb_typeof(v) <> 'boolean' THEN RAISE EXCEPTION 'Invalid boolean field: %',n;
    ELSIF t='select' AND f ? 'options' AND NOT (f->'options' @> jsonb_build_array(v)) THEN RAISE EXCEPTION 'Invalid selection: %',n;
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION sync_mutations(p_mutations JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_tenant UUID := auth.tenant_id(); v_role TEXT := auth.user_role(); m JSONB; p JSONB;
  v_id UUID; v_mutation UUID; v_entity entities; v_record records; v_existing JSONB; v_data JSONB;
  v_action TEXT; v_name TEXT; v_field TEXT; v_delta NUMERIC; v_amount NUMERIC; v_count INT := 0; v_duplicates INT := 0;
  v_plan TEXT; v_has_invoice BOOLEAN; v_current NUMERIC;
BEGIN
  IF v_tenant IS NULL OR v_role NOT IN ('owner','manager','cashier') THEN RAISE EXCEPTION 'Write permission required' USING ERRCODE='42501'; END IF;
  IF jsonb_typeof(p_mutations) <> 'array' OR jsonb_array_length(p_mutations) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'A sync batch must contain 1 to 500 mutations';
  END IF;
  IF octet_length(p_mutations::text) > 5242880 THEN RAISE EXCEPTION 'Sync batch exceeds 5 MB'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_tenant::text,0));
  SELECT plan INTO v_plan FROM tenants WHERE id=v_tenant;
  v_has_invoice := EXISTS(SELECT 1 FROM jsonb_array_elements(p_mutations) x WHERE x->>'entity'='invoice' AND x->>'action'='create');
  FOR m IN SELECT value FROM jsonb_array_elements(p_mutations) LOOP
    v_mutation := (m->>'id')::uuid; p := m->'payload'; v_id := (p->>'id')::uuid;
    IF v_mutation IS NULL OR v_id IS NULL OR jsonb_typeof(p) <> 'object' THEN RAISE EXCEPTION 'Mutation and record UUIDs are required'; END IF;
    SELECT mutation INTO v_existing FROM sync_receipts WHERE tenant_id=v_tenant AND mutation_id=v_mutation;
    IF FOUND THEN
      IF v_existing <> m THEN RAISE EXCEPTION 'Mutation UUID was already used for different data'; END IF;
      v_duplicates := v_duplicates+1; CONTINUE;
    END IF;
    v_name := m->>'entity'; v_action := m->>'action';
    SELECT e.* INTO v_entity FROM entities e JOIN apps a ON a.id=e.app_id
      WHERE a.tenant_id=v_tenant AND a.is_active AND e.name=v_name ORDER BY a.created_at LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'Unknown entity: %',v_name; END IF;
    IF v_action NOT IN ('create','update','delete','adjust') THEN RAISE EXCEPTION 'Unknown mutation action'; END IF;
    IF v_role='cashier' AND NOT ((v_name IN ('customer','invoice','ledger') AND v_action IN ('create','update','adjust'))
      OR (v_name='product' AND v_action='adjust' AND v_has_invoice)) THEN RAISE EXCEPTION 'Role cannot edit this entity' USING ERRCODE='42501'; END IF;
    SELECT * INTO v_record FROM records WHERE id=v_id FOR UPDATE;
    IF FOUND AND (v_record.tenant_id <> v_tenant OR v_record.entity_id <> v_entity.id) THEN
      RAISE EXCEPTION 'Record not found' USING ERRCODE='42501';
    END IF;
    IF v_action='create' THEN
      IF v_record.id IS NOT NULL THEN RAISE EXCEPTION 'Record already exists'; END IF;
      IF v_name='product' AND (v_plan='free' OR v_plan='basic') THEN
        SELECT count(*) INTO v_count FROM records WHERE tenant_id=v_tenant AND entity_id=v_entity.id AND deleted_at IS NULL;
        IF v_count >= CASE v_plan WHEN 'free' THEN 50 ELSE 1000 END THEN RAISE EXCEPTION 'Product limit reached for this plan'; END IF;
      END IF;
      IF v_name='invoice' AND v_plan='free' AND (SELECT count(*) FROM records WHERE tenant_id=v_tenant AND entity_id=v_entity.id
        AND created_at >= date_trunc('month',now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata') >= 100 THEN
        RAISE EXCEPTION 'Monthly invoice limit reached for this plan';
      END IF;
      v_data := p - 'tenant_id' - 'entity_id';
      PERFORM validate_record_data(v_entity.schema,v_data);
      INSERT INTO records(id,tenant_id,entity_id,data,created_by,created_at,updated_at)
      VALUES(v_id,v_tenant,v_entity.id,v_data,auth.uid(),clock_timestamp(),clock_timestamp());
    ELSE
      IF v_record.id IS NULL OR v_record.deleted_at IS NOT NULL THEN RAISE EXCEPTION 'Record not found'; END IF;
      IF v_name IN ('invoice','ledger') THEN RAISE EXCEPTION 'Posted invoices and ledger entries are immutable; create a correcting entry'; END IF;
      IF v_action='delete' THEN
        UPDATE records SET deleted_at=clock_timestamp() WHERE id=v_id;
      ELSIF v_action='adjust' THEN
        v_field := COALESCE(p->>'field',CASE v_name WHEN 'product' THEN 'stock' WHEN 'customer' THEN 'outstanding' END);
        IF NOT ((v_name='product' AND v_field='stock') OR (v_name='customer' AND v_field='outstanding')) THEN RAISE EXCEPTION 'Unsupported adjustment'; END IF;
        IF jsonb_typeof(p->'delta') <> 'number' THEN RAISE EXCEPTION 'Adjustment delta must be numeric'; END IF;
        v_delta := (p->>'delta')::numeric;
        IF v_delta IS NULL OR v_delta=0 OR abs(v_delta)>1000000000 THEN RAISE EXCEPTION 'Invalid adjustment delta'; END IF;
        IF v_role='cashier' AND v_name='product' AND v_delta > 0 THEN RAISE EXCEPTION 'Only managers can increase stock' USING ERRCODE='42501'; END IF;
        v_current := COALESCE((v_record.data->>v_field)::numeric,0); v_amount := v_current + v_delta;
        IF v_amount < 0 THEN RAISE EXCEPTION 'Adjustment would make % negative',v_field; END IF;
        UPDATE records SET data=jsonb_set(data,ARRAY[v_field],to_jsonb(v_amount)) WHERE id=v_id;
      ELSE
        IF v_role='cashier' AND v_name='customer' AND p ? 'outstanding' AND (p->'outstanding') IS DISTINCT FROM v_record.data->'outstanding' THEN
          RAISE EXCEPTION 'Use a ledger adjustment to change customer balance';
        END IF;
        v_data := merge_json_objects(v_record.data,p - 'tenant_id' - 'entity_id');
        PERFORM validate_record_data(v_entity.schema,v_data);
        UPDATE records SET data=v_data WHERE id=v_id;
      END IF;
    END IF;
    INSERT INTO sync_receipts(tenant_id,mutation_id,user_id,mutation) VALUES(v_tenant,v_mutation,auth.uid(),m);
    INSERT INTO audit_log(tenant_id,user_id,action,entity,record_id,diff)
    VALUES(v_tenant,auth.uid(),'record.' || v_action,v_name,v_id,jsonb_build_object('mutation_id',v_mutation));
  END LOOP;
  RETURN jsonb_build_object('applied',jsonb_array_length(p_mutations)-v_duplicates,'duplicates',v_duplicates);
END;
$$;

CREATE OR REPLACE FUNCTION pull_records(p_since TIMESTAMPTZ DEFAULT NULL,p_after_id UUID DEFAULT NULL,p_limit INT DEFAULT 500)
RETURNS TABLE(id UUID,tenant_id UUID,entity TEXT,entity_id UUID,data JSONB,created_at TIMESTAMPTZ,updated_at TIMESTAMPTZ,deleted_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_tenant UUID := auth.tenant_id();
BEGIN
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'Select an active shop' USING ERRCODE='42501'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_tenant::text,0));
  RETURN QUERY SELECT r.id,r.tenant_id,e.name,r.entity_id,r.data,r.created_at,r.updated_at,r.deleted_at
  FROM records r JOIN entities e ON e.id=r.entity_id JOIN apps a ON a.id=e.app_id
  WHERE r.tenant_id=v_tenant AND a.tenant_id=v_tenant
    AND (p_since IS NULL OR r.updated_at > p_since OR (r.updated_at=p_since AND (p_after_id IS NULL OR r.id>p_after_id)))
  ORDER BY r.updated_at,r.id LIMIT GREATEST(1,LEAST(p_limit,1000));
END;
$$;
REVOKE ALL ON FUNCTION sync_mutations(JSONB),pull_records(TIMESTAMPTZ,UUID,INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION sync_mutations(JSONB),pull_records(TIMESTAMPTZ,UUID,INT) TO authenticated;
