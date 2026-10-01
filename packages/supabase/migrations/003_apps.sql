-- Create apps table (each tenant can have multiple apps/modules)
CREATE TABLE IF NOT EXISTS apps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    template_key TEXT,
    config JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create entities table (dynamic low-code entity schemas)
CREATE TABLE IF NOT EXISTS entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    label TEXT NOT NULL,
    icon TEXT DEFAULT 'file',
    schema JSONB NOT NULL,
    is_system BOOLEAN DEFAULT false,
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(app_id, name)
);

-- Create records table (all dynamic data lives here as JSONB)
CREATE TABLE IF NOT EXISTS records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    entity_id UUID NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    data JSONB NOT NULL DEFAULT '{}',
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Create indexes for performance
CREATE INDEX idx_apps_tenant ON apps(tenant_id);
CREATE INDEX idx_entities_app ON entities(app_id);
CREATE INDEX idx_entities_app_name ON entities(app_id, name);
CREATE INDEX idx_records_tenant_entity ON records(tenant_id, entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_records_entity ON records(entity_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_records_tenant ON records(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_records_created_by ON records(created_by);

-- GIN index for JSONB queries (critical for low-code performance)
CREATE INDEX idx_records_data_gin ON records USING GIN(data jsonb_path_ops);

-- Add triggers
CREATE TRIGGER update_apps_updated_at
    BEFORE UPDATE ON apps
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_entities_updated_at
    BEFORE UPDATE ON entities
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_records_updated_at
    BEFORE UPDATE ON records
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE apps IS 'Low-code apps within each tenant';
COMMENT ON TABLE entities IS 'Dynamic entity schemas stored as JSON - the core of low-code engine';
COMMENT ON TABLE records IS 'All dynamic data stored as JSONB for maximum flexibility';
COMMENT ON COLUMN records.data IS 'JSONB data conforming to entity schema - indexed with GIN for fast queries';
