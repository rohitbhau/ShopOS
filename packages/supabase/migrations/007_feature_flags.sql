-- Create feature flags table for gradual rollout
CREATE TABLE IF NOT EXISTS feature_flags (
    key TEXT PRIMARY KEY,
    enabled BOOLEAN DEFAULT false,
    rollout_percent INT DEFAULT 0 CHECK (rollout_percent >= 0 AND rollout_percent <= 100),
    description TEXT,
    metadata JSONB DEFAULT '{}',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create tenant-specific feature overrides
CREATE TABLE IF NOT EXISTS feature_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    feature_key TEXT NOT NULL REFERENCES feature_flags(key) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tenant_id, feature_key)
);

-- Create indexes
CREATE INDEX idx_feature_overrides_tenant ON feature_overrides(tenant_id);
CREATE INDEX idx_feature_overrides_feature ON feature_overrides(feature_key);

-- Add trigger
CREATE TRIGGER update_feature_flags_updated_at
    BEFORE UPDATE ON feature_flags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert default feature flags
INSERT INTO feature_flags (key, enabled, rollout_percent, description) VALUES
('whatsapp_notifications', true, 100, 'WhatsApp notifications for invoices and reminders'),
('advanced_reports', true, 100, 'Advanced analytics and reports'),
('loyalty_program', false, 0, 'Customer loyalty points and rewards'),
('api_access', false, 0, 'REST API access for integrations'),
('custom_domain', false, 0, 'Custom domain for online store'),
('multi_shop', false, 0, 'Multiple shops per account'),
('voice_input', false, 0, 'Voice input for billing and data entry'),
('barcode_generation', true, 100, 'Generate barcodes for products'),
('thermal_print', true, 100, 'Thermal printer support'),
('stock_predictions', false, 10, 'AI-powered stock level predictions')
ON CONFLICT (key) DO NOTHING;

-- Add comments
COMMENT ON TABLE feature_flags IS 'Global feature flags with percentage-based rollout';
COMMENT ON TABLE feature_overrides IS 'Tenant-specific feature flag overrides for beta testing or plan-based access';
