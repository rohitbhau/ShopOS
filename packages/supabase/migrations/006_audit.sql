-- Create audit log table for compliance and debugging
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity TEXT,
    record_id UUID,
    diff JSONB,
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for audit queries
CREATE INDEX idx_audit_log_tenant ON audit_log(tenant_id, created_at DESC);
CREATE INDEX idx_audit_log_user ON audit_log(user_id, created_at DESC);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_entity_record ON audit_log(entity, record_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);

-- Add GIN index for metadata queries
CREATE INDEX idx_audit_log_metadata_gin ON audit_log USING GIN(metadata jsonb_path_ops);

-- Add comment
COMMENT ON TABLE audit_log IS 'Comprehensive audit trail for all user actions - immutable log';

-- Actions tracked:
-- auth.login, auth.logout
-- tenant.created, tenant.updated, tenant.deleted
-- record.created, record.updated, record.deleted
-- subscription.created, subscription.updated, subscription.cancelled
-- user.invited, user.removed, user.role_changed
-- workflow.executed
-- report.exported
-- data.imported, data.exported
