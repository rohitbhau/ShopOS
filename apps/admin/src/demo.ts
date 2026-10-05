import { type Snapshot, type Entity, type Workflow, type TenantDetail, validateEntity, validateWorkflow } from '../../../packages/shared/shopos';

export const demoStorageKey = 'shopos-admin-demo-v2';
const tenantId = '00000000-0000-4000-8000-000000000001';
const appId = '00000000-0000-4000-8000-000000000002';
const productId = '00000000-0000-4000-8000-000000000003';
export function demoSnapshot(): Snapshot {
  const customer: Entity['schema'] = { fields: [{ name: 'name', label: 'Name', type: 'text', required: true }, { name: 'phone', label: 'Phone', type: 'text' }] };
  const schemas = [
    ['retail_basic', 'Retail / Kirana', ['product', 'customer', 'invoice', 'supplier', 'purchase']],
    ['pharmacy', 'Pharmacy', ['medicine', 'batch', 'prescription', 'customer']],
    ['salon', 'Salon', ['service', 'staff', 'appointment', 'customer', 'package']],
    ['restaurant', 'Restaurant', ['menu_item', 'table', 'order', 'kot', 'customer']],
    ['boutique', 'Boutique', ['garment', 'customer', 'order', 'measurement']],
    ['repair', 'Repair', ['device', 'job_card', 'spare_part', 'customer', 'invoice']],
  ] as const;
  return {
    tenants: [{ id: tenantId, name: 'Demo Corner Store', shop_type: 'retail', plan: 'free', is_active: true, created_at: new Date().toISOString(), trial_ends_at: new Date(Date.now() + 14 * 86400000).toISOString() }],
    apps: [{ id: appId, tenant_id: tenantId, name: 'Demo shop', schema_version: 1 }],
    entities: [{ id: productId, app_id: appId, name: 'product', label: 'Product', is_system: true, schema: { fields: [{ name: 'name', label: 'Product name', type: 'text', required: true }, { name: 'price', label: 'Selling price', type: 'decimal', min: 0, required: true }, { name: 'stock', label: 'Stock', type: 'number', default: 0, min: 0 }], list: { columns: ['name', 'price', 'stock'] } } }, { id: '00000000-0000-4000-8000-000000000004', app_id: appId, name: 'customer', label: 'Customer', schema: customer }],
    workflows: [{ id: '00000000-0000-4000-8000-000000000005', app_id: appId, name: 'Low stock alert', is_active: false, trigger: { type: 'record.updated', entity: 'product' }, conditions: [{ field: 'stock', op: '<=', value: 5 }], actions: [{ type: 'send_whatsapp', to: '{{tenant.phone}}', template: 'low_stock_alert', variables: { product: '{{record.name}}', stock: '{{record.stock}}' } } ] }],
    subscriptions: [{ id: '00000000-0000-4000-8000-000000000006', tenant_id: tenantId, plan: 'free', status: 'trialing' }], invoices: [], audit: [], whatsapp: [],
    flags: [{ key: 'advanced_reports', enabled: true, rollout_percent: 100, description: 'Advanced analytics and reports' }, { key: 'whatsapp_notifications', enabled: false, rollout_percent: 0, description: 'WhatsApp utility messages' }],
    templates: schemas.map(([key, name, entities]) => ({ key, name, entities: entities.map((entity) => ({ name: entity, label: entity.replaceAll('_', ' '), schema: customer })), workflows: [] })),
    notices: ['Local demo: sample tenants and simplified templates. Changes stay in this browser. No messages or payments are sent.'],
  };
}
export function demoDetail(snapshot: Snapshot, selectedTenant: string): TenantDetail {
  return { members: [{ id: 'demo-owner', role: 'owner', is_active: true, profiles: { name: 'Demo shop owner' } }], records: [], usage: { records: 0 }, audit: snapshot.audit.filter((item) => item.tenant_id === selectedTenant) };
}
export function mutateDemo(snapshot: Snapshot, input: Record<string, unknown>): Snapshot {
  const next = structuredClone(snapshot);
  const tenant = next.tenants.find((item) => item.id === input.tenant_id);
  const app = next.apps.find((item) => item.tenant_id === input.tenant_id);
  if (input.action !== 'update_flag' && (!tenant || !app)) throw new Error('Select a shop first.');
  switch (input.action) {
    case 'publish_entity': {
      const entity = structuredClone(input.entity) as Entity;
      const errors = validateEntity(entity); if (errors.length) throw new Error(errors.join(' '));
      const current = next.entities.find((item) => item.id === entity.id);
      if (current?.is_system && current.name !== entity.name) throw new Error('System entity names cannot change.');
      if (next.entities.some((item) => item.app_id === entity.app_id && item.name === entity.name && item.id !== entity.id)) throw new Error('An entity with that name already exists.');
      entity.id ||= crypto.randomUUID(); entity.app_id = app!.id;
      next.entities = [...next.entities.filter((item) => item.id !== entity.id), entity];
      app!.schema_version = (app!.schema_version ?? 1) + 1; app!.published_at = new Date().toISOString(); break;
    }
    case 'save_workflow': {
      const workflow = structuredClone(input.workflow) as Workflow;
      const errors = validateWorkflow(workflow); if (errors.length) throw new Error(errors.join(' '));
      workflow.id ||= crypto.randomUUID(); workflow.app_id = app!.id;
      next.workflows = [...next.workflows.filter((item) => item.id !== workflow.id), workflow]; break;
    }
    case 'update_flag': { const flag = input.flag as Snapshot['flags'][number]; if (!next.flags.some((item) => item.key === flag.key)) throw new Error('Unknown flag.'); next.flags = next.flags.map((item) => item.key === flag.key ? flag : item); break; }
    case 'extend_trial': { const days = Number(input.days); if (!Number.isInteger(days) || days < 1 || days > 90) throw new Error('Trial extension must be 1–90 days.'); tenant!.trial_ends_at = new Date(Math.max(Date.now(), Date.parse(tenant!.trial_ends_at ?? '') || 0) + days * 86400000).toISOString(); break; }
    case 'subscription_action': {
      if (input.subscription_action === 'refund') { const invoice = next.invoices.find((item) => item.id === input.invoice_id && item.tenant_id === tenant!.id); if (!invoice || invoice.status !== 'paid') throw new Error('Select a paid invoice.'); invoice.status = 'refunded'; }
      else { const subscription = next.subscriptions.find((item) => item.tenant_id === tenant!.id); if (!subscription) throw new Error('No subscription found.'); if (input.subscription_action === 'cancel') subscription.status = 'cancelled'; else throw new Error('Paid plan changes require live Razorpay configuration.'); } break;
    }
    case 'templates': {
      const template = next.templates.find((item) => item.key === input.template_key); if (!template) throw new Error('Template not found.');
      for (const entity of template.entities) if (!next.entities.some((item) => item.app_id === app!.id && item.name === entity.name)) next.entities.push({ ...entity, app_id: app!.id, id: crypto.randomUUID() });
      app!.schema_version = (app!.schema_version ?? 1) + 1; break;
    }
    case 'readonly_view': break;
    default: throw new Error('Unknown demo action.');
  }
  next.audit.unshift({ id: crypto.randomUUID(), tenant_id: tenant?.id, action: `admin.${input.action}`, created_at: new Date().toISOString(), metadata: { mode: 'local-demo' } });
  return next;
}
