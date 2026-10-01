-- Create tenants table for multi-tenant isolation
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    shop_type TEXT NOT NULL CHECK (shop_type IN ('retail', 'pharmacy', 'salon', 'restaurant', 'boutique', 'repair', 'other')),
    phone TEXT,
    address JSONB DEFAULT '{}',
    gstin TEXT,
    logo_url TEXT,
    plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'basic', 'standard', 'pro')),
    trial_ends_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '14 days'),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for lookups
CREATE INDEX idx_tenants_phone ON tenants(phone);
CREATE INDEX idx_tenants_plan ON tenants(plan);
CREATE INDEX idx_tenants_trial ON tenants(trial_ends_at) WHERE is_active = true;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger for tenants
CREATE TRIGGER update_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comment
COMMENT ON TABLE tenants IS 'Multi-tenant shops - each shop is a separate tenant with strict data isolation';
