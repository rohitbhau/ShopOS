-- Create workflows table for automation
CREATE TABLE IF NOT EXISTS workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    trigger JSONB NOT NULL,
    conditions JSONB DEFAULT '[]',
    actions JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    execution_count INT DEFAULT 0,
    last_executed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create workflow_executions for logging
CREATE TABLE IF NOT EXISTS workflow_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    trigger_data JSONB,
    status TEXT NOT NULL CHECK (status IN ('success', 'failed', 'partial')),
    result JSONB,
    error TEXT,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_workflows_app ON workflows(app_id);
CREATE INDEX idx_workflows_active ON workflows(app_id) WHERE is_active = true;
CREATE INDEX idx_workflow_executions_workflow ON workflow_executions(workflow_id);
CREATE INDEX idx_workflow_executions_tenant ON workflow_executions(tenant_id);
CREATE INDEX idx_workflow_executions_executed_at ON workflow_executions(executed_at);

-- Add triggers
CREATE TRIGGER update_workflows_updated_at
    BEFORE UPDATE ON workflows
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add comments
COMMENT ON TABLE workflows IS 'Automation workflows with triggers, conditions, and actions';
COMMENT ON TABLE workflow_executions IS 'Execution log for workflows for debugging and auditing';

-- Example workflow structure in trigger field:
-- {"type": "record.updated", "entity": "product"}
-- 
-- Example conditions:
-- [{"field": "stock", "op": "<=", "value": 5}]
--
-- Example actions:
-- [{"type": "send_whatsapp", "to": "{{tenant.owner_phone}}", "template": "low_stock_alert", "variables": {"product": "{{record.name}}", "stock": "{{record.stock}}"}}]
