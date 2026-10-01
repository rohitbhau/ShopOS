-- Enable Row Level Security on all tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE apps ENABLE ROW LEVEL SECURITY;
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE records ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices_saas ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_overrides ENABLE ROW LEVEL SECURITY;

-- Helper functions to extract JWT claims
CREATE OR REPLACE FUNCTION auth.tenant_id() 
RETURNS UUID AS $$
  SELECT NULLIF(
    CURRENT_SETTING('request.jwt.claims', TRUE)::JSON->>'tenant_id',
    ''
  )::UUID;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION auth.user_role() 
RETURNS TEXT AS $$
  SELECT COALESCE(
    CURRENT_SETTING('request.jwt.claims', TRUE)::JSON->>'role',
    'viewer'
  );
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION auth.user_id() 
RETURNS UUID AS $$
  SELECT NULLIF(
    CURRENT_SETTING('request.jwt.claims', TRUE)::JSON->>'sub',
    ''
  )::UUID;
$$ LANGUAGE SQL STABLE;

-- Tenants policies
CREATE POLICY tenant_read ON tenants
    FOR SELECT
    USING (id = auth.tenant_id());

CREATE POLICY tenant_update ON tenants
    FOR UPDATE
    USING (id = auth.tenant_id())
    WITH CHECK (id = auth.tenant_id());

-- Profiles policies
CREATE POLICY profile_read ON profiles
    FOR SELECT
    USING (
        id = auth.user_id() OR
        id IN (
            SELECT user_id FROM memberships 
            WHERE tenant_id = auth.tenant_id()
        )
    );

CREATE POLICY profile_update ON profiles
    FOR UPDATE
    USING (id = auth.user_id())
    WITH CHECK (id = auth.user_id());

-- Memberships policies
CREATE POLICY membership_read ON memberships
    FOR SELECT
    USING (tenant_id = auth.tenant_id() OR user_id = auth.user_id());

CREATE POLICY membership_manage ON memberships
    FOR ALL
    USING (
        tenant_id = auth.tenant_id() AND
        auth.user_role() IN ('owner', 'manager')
    )
    WITH CHECK (
        tenant_id = auth.tenant_id() AND
        auth.user_role() IN ('owner', 'manager')
    );

-- Apps policies (strict tenant isolation)
CREATE POLICY apps_isolation ON apps
    FOR ALL
    USING (tenant_id = auth.tenant_id())
    WITH CHECK (tenant_id = auth.tenant_id());

-- Entities policies
CREATE POLICY entities_read ON entities
    FOR SELECT
    USING (
        app_id IN (
            SELECT id FROM apps WHERE tenant_id = auth.tenant_id()
        )
    );

CREATE POLICY entities_manage ON entities
    FOR ALL
    USING (
        app_id IN (
            SELECT id FROM apps WHERE tenant_id = auth.tenant_id()
        ) AND
        auth.user_role() IN ('owner', 'manager')
    )
    WITH CHECK (
        app_id IN (
            SELECT id FROM apps WHERE tenant_id = auth.tenant_id()
        ) AND
        auth.user_role() IN ('owner', 'manager')
    );

-- Records policies (most critical - handles all dynamic data)
CREATE POLICY records_read ON records
    FOR SELECT
    USING (
        tenant_id = auth.tenant_id() AND
        deleted_at IS NULL
    );

CREATE POLICY records_create ON records
    FOR INSERT
    WITH CHECK (
        tenant_id = auth.tenant_id() AND
        auth.user_role() IN ('owner', 'manager', 'cashier')
    );

CREATE POLICY records_update ON records
    FOR UPDATE
    USING (
        tenant_id = auth.tenant_id() AND
        auth.user_role() IN ('owner', 'manager', 'cashier')
    )
    WITH CHECK (
        tenant_id = auth.tenant_id() AND
        auth.user_role() IN ('owner', 'manager', 'cashier')
    );

CREATE POLICY records_delete ON records
    FOR DELETE
    USING (
        tenant_id = auth.tenant_id() AND
        auth.user_role() IN ('owner', 'manager')
    );

-- Workflows policies
CREATE POLICY workflows_isolation ON workflows
    FOR ALL
    USING (
        app_id IN (
            SELECT id FROM apps WHERE tenant_id = auth.tenant_id()
        )
    )
    WITH CHECK (
        app_id IN (
            SELECT id FROM apps WHERE tenant_id = auth.tenant_id()
        )
    );

CREATE POLICY workflow_executions_read ON workflow_executions
    FOR SELECT
    USING (tenant_id = auth.tenant_id());

-- Subscriptions policies
CREATE POLICY subscriptions_isolation ON subscriptions
    FOR ALL
    USING (tenant_id = auth.tenant_id())
    WITH CHECK (tenant_id = auth.tenant_id());

CREATE POLICY invoices_saas_isolation ON invoices_saas
    FOR ALL
    USING (tenant_id = auth.tenant_id())
    WITH CHECK (tenant_id = auth.tenant_id());

CREATE POLICY payment_methods_isolation ON payment_methods
    FOR ALL
    USING (tenant_id = auth.tenant_id())
    WITH CHECK (tenant_id = auth.tenant_id());

-- Audit log policies (read-only for users, write via triggers)
CREATE POLICY audit_log_read ON audit_log
    FOR SELECT
    USING (
        tenant_id = auth.tenant_id() AND
        auth.user_role() IN ('owner', 'manager')
    );

-- Feature flags policies (read-only for all)
CREATE POLICY feature_flags_read_all ON feature_flags
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY feature_overrides_read ON feature_overrides
    FOR SELECT
    USING (tenant_id = auth.tenant_id());

-- Add comments
COMMENT ON POLICY tenant_read ON tenants IS 'Users can only read their own tenant data';
COMMENT ON POLICY records_read ON records IS 'Critical: strict tenant isolation for all dynamic data';
COMMENT ON FUNCTION auth.tenant_id() IS 'Extract tenant_id from JWT custom claim - set by auth-set-tenant-claim edge function';
