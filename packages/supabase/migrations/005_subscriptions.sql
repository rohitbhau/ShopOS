-- Create subscriptions table for Razorpay integration
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    plan TEXT NOT NULL CHECK (plan IN ('free', 'basic', 'standard', 'pro')),
    status TEXT NOT NULL CHECK (status IN ('active', 'trialing', 'past_due', 'cancelled', 'halted')),
    razorpay_sub_id TEXT UNIQUE,
    razorpay_customer_id TEXT,
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT false,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create invoices table for SaaS billing (separate from shop invoices)
CREATE TABLE IF NOT EXISTS invoices_saas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    amount_paise INT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('draft', 'pending', 'paid', 'failed', 'refunded')),
    razorpay_payment_id TEXT,
    razorpay_order_id TEXT,
    invoice_number TEXT UNIQUE,
    due_date TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create payment_methods table
CREATE TABLE IF NOT EXISTS payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    razorpay_customer_id TEXT NOT NULL,
    method_type TEXT NOT NULL,
    details JSONB,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_subscriptions_tenant ON subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_razorpay ON subscriptions(razorpay_sub_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_invoices_saas_tenant ON invoices_saas(tenant_id);
CREATE INDEX idx_invoices_saas_subscription ON invoices_saas(subscription_id);
CREATE INDEX idx_invoices_saas_status ON invoices_saas(status);
CREATE INDEX idx_payment_methods_tenant ON payment_methods(tenant_id);

-- Add triggers
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoices_saas_updated_at
    BEFORE UPDATE ON invoices_saas
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE subscriptions IS 'SaaS subscription management with Razorpay integration';
COMMENT ON TABLE invoices_saas IS 'Invoices for SaaS billing (not shop invoices which are in records)';
COMMENT ON TABLE payment_methods IS 'Saved payment methods for recurring billing';
