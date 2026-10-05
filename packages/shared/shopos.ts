/** Wire contracts shared by the admin console and backend clients. */
export type Plan = 'free' | 'basic' | 'standard' | 'pro';
export const planPrices: Record<Plan, number> = { free: 0, basic: 149, standard: 299, pro: 599 };
export const fieldTypes = ['text', 'textarea', 'number', 'decimal', 'date', 'datetime', 'bool', 'select', 'multiselect', 'file', 'image', 'relation', 'barcode', 'qr', 'signature', 'json', 'computed'] as const;
export type Field = { name: string; label?: string; type: typeof fieldTypes[number]; required?: boolean; readonly?: boolean; options?: string[]; min?: number; max?: number; pattern?: string; target?: string; expression?: string; default?: unknown };
export type Schema = { fields: Field[]; list?: { columns: string[] }; dashboard?: { metrics: string[] } };
export type Entity = { id: string; app_id: string; name: string; label: string; is_system?: boolean; schema: Schema };
export type Tenant = { id: string; name: string; shop_type: string; plan: Plan; is_active: boolean; phone?: string; trial_ends_at?: string; created_at: string };
export type App = { id: string; tenant_id: string; name: string; schema_version?: number; published_at?: string };
export type Condition = { field: string; op: '==' | '!=' | '>' | '>=' | '<' | '<=' | 'contains'; value: unknown };
export type Workflow = { id: string; app_id: string; name: string; is_active: boolean; trigger: { type: string; entity?: string; cron?: string }; conditions: Condition[]; actions: Array<Record<string, unknown> & { type: string }> };
export type Subscription = { id: string; tenant_id: string; plan: Plan; status: string; current_period_end?: string; razorpay_sub_id?: string; created_at?: string };
export type SaaSInvoice = { id: string; tenant_id: string; amount_paise: number; status: string; created_at: string; razorpay_payment_id?: string };
export type Audit = { id: number | string; tenant_id?: string; action: string; entity?: string; created_at: string; metadata?: unknown; diff?: unknown };
export type WhatsAppLog = { id: string; tenant_id: string; recipient: string; template: string; status: string; created_at: string; error?: string };
export type FeatureFlag = { key: string; enabled: boolean; rollout_percent: number; description?: string; updated_at?: string };
export type Template = { key: string; name: string; entities: Array<Omit<Entity, 'id' | 'app_id'>>; workflows: Array<Omit<Workflow, 'id' | 'app_id'>>; dashboard?: unknown };
export type Snapshot = { tenants: Tenant[]; apps: App[]; entities: Entity[]; workflows: Workflow[]; subscriptions: Subscription[]; invoices: SaaSInvoice[]; audit: Audit[]; whatsapp: WhatsAppLog[]; flags: FeatureFlag[]; templates: Template[]; notices?: string[] };
export type TenantDetail = { members: Array<{ id: string; role: string; is_active: boolean; profiles?: { name?: string; phone?: string } }>; records: Array<{ id: string; entity_id: string; data: Record<string, unknown>; updated_at: string }>; usage: { records: number }; audit: Audit[] };

const forbiddenNames = new Set(['__proto__', 'prototype', 'constructor']);
export function validName(value: string): boolean { return /^[a-z][a-z0-9_]{0,62}$/.test(value) && !forbiddenNames.has(value); }
export function validateEntity(entity: Pick<Entity, 'name' | 'label' | 'schema'>): string[] {
  const errors: string[] = [];
  if (!validName(entity.name)) errors.push('Entity name must start with a letter and contain only lowercase letters, digits, and underscores.');
  if (!entity.label?.trim()) errors.push('Entity label is required.');
  if (!Array.isArray(entity.schema?.fields) || !entity.schema.fields.length) return [...errors, 'Add at least one field.'];
  if (entity.schema.fields.length > 100) errors.push('An entity can have at most 100 fields.');
  const names = new Set<string>();
  for (const field of entity.schema.fields) {
    if (!validName(field.name) || names.has(field.name)) errors.push(`Invalid or duplicate field name: ${field.name}`);
    names.add(field.name);
    if (!fieldTypes.includes(field.type)) errors.push(`Unsupported field type: ${field.type}`);
    if (field.min !== undefined && field.max !== undefined && field.min > field.max) errors.push(`${field.name}: minimum exceeds maximum.`);
    if (['select', 'multiselect'].includes(field.type) && (!Array.isArray(field.options) || !field.options.length)) errors.push(`${field.name}: add choices.`);
    if (field.type === 'relation' && !validName(field.target ?? '')) errors.push(`${field.name}: choose a target entity.`);
    if (field.expression || field.type === 'computed') {
      try { parseExpression(field.expression ?? ''); } catch (error) { errors.push(`${field.name}: ${(error as Error).message}`); }
    }
    if (field.pattern) { try { new RegExp(field.pattern); } catch { errors.push(`${field.name}: invalid validation pattern.`); } }
  }
  for (const column of [...(entity.schema.list?.columns ?? []), ...(entity.schema.dashboard?.metrics ?? [])]) if (!names.has(column)) errors.push(`Unknown layout field: ${column}`);
  return errors;
}

// A small expression parser, never eval/Function. Property access is own-only.
type Node = { kind: 'value'; value: unknown } | { kind: 'path'; value: string } | { kind: 'call'; value: string; args: Node[] } | { kind: 'binary'; value: string; left: Node; right: Node } | { kind: 'negative'; node: Node };
const functions = new Set(['sum', 'count', 'if', 'concat', 'min', 'max', 'round']);
function parseExpression(source: string): Node {
  if (source.length > 500 || !source.trim()) throw new Error('Expression must contain 1–500 characters.');
  const tokens: string[] = []; let offset = 0;
  while (offset < source.length) {
    if (/\s/.test(source[offset])) { offset++; continue; }
    const token = /^(?:\d+(?:\.\d+)?|[a-zA-Z_][\w]*(?:\.[a-zA-Z_][\w]*)*|'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|<=|>=|==|!=|[()+\-*/%,<>])/.exec(source.slice(offset));
    if (!token) throw new Error('Unsupported expression syntax.');
    tokens.push(token[0]); offset += token[0].length;
  }
  let index = 0;
  const precedence: Record<string, number> = { '==': 1, '!=': 1, '<': 2, '<=': 2, '>': 2, '>=': 2, '+': 3, '-': 3, '*': 4, '/': 4, '%': 4 };
  function atom(): Node {
    const token = tokens[index++];
    if (!token) throw new Error('Incomplete expression.');
    if (token === '-') return { kind: 'negative', node: atom() };
    if (token === '(') { const node = expression(0); if (tokens[index++] !== ')') throw new Error('Missing closing parenthesis.'); return node; }
    if (/^\d/.test(token)) return { kind: 'value', value: Number(token) };
    if (/^['"]/.test(token)) return { kind: 'value', value: token.slice(1, -1).replace(/\\(['"\\])/g, '$1') };
    if (!/^[a-zA-Z_]/.test(token) || token.split('.').some((part) => forbiddenNames.has(part))) throw new Error('Invalid field reference.');
    if (tokens[index] === '(') {
      if (!functions.has(token)) throw new Error(`Unknown function: ${token}`);
      index++; const args: Node[] = [];
      if (tokens[index] !== ')') do { args.push(expression(0)); if (tokens[index] !== ',') break; index++; } while (index < tokens.length);
      if (tokens[index++] !== ')') throw new Error('Missing closing parenthesis.');
      if ((token === 'if' && args.length !== 3) || (['sum', 'count'].includes(token) && args.length !== 1) || (token === 'round' && ![1, 2].includes(args.length)) || (!args.length)) throw new Error(`Invalid argument count for ${token}.`);
      return { kind: 'call', value: token, args };
    }
    if (['true', 'false', 'null'].includes(token)) return { kind: 'value', value: token === 'true' ? true : token === 'false' ? false : null };
    return { kind: 'path', value: token };
  }
  function expression(min: number): Node {
    let left = atom();
    while (precedence[tokens[index]] !== undefined && precedence[tokens[index]] >= min) { const op = tokens[index++]; const right = expression(precedence[op] + 1); left = { kind: 'binary', value: op, left, right }; }
    return left;
  }
  const tree = expression(0); if (index !== tokens.length) throw new Error('Unexpected expression token.'); return tree;
}
export function readPath(data: unknown, path: string): unknown {
  const parts = path.split('.');
  function read(value: unknown, position: number): unknown {
    if (position === parts.length) return value;
    if (Array.isArray(value)) return value.map((item) => read(item, position));
    if (!value || typeof value !== 'object' || forbiddenNames.has(parts[position]) || !Object.prototype.hasOwnProperty.call(value, parts[position])) return undefined;
    return read((value as Record<string, unknown>)[parts[position]], position + 1);
  }
  return read(data, 0);
}
export function evaluateExpression(source: string, data: Record<string, unknown>): unknown {
  const numeric = (value: unknown) => { const number = Number(value ?? 0); if (!Number.isFinite(number)) throw new Error('Expression needs a finite number.'); return number; };
  function run(node: Node): unknown {
    if (node.kind === 'value') return node.value;
    if (node.kind === 'path') return readPath(data, node.value);
    if (node.kind === 'negative') return -numeric(run(node.node));
    if (node.kind === 'call') {
      if (node.value === 'if') return run(node.args[run(node.args[0]) ? 1 : 2]);
      const args = node.args.map(run); const values = args.flat();
      switch (node.value) {
        case 'sum': return values.reduce<number>((total, value) => total + numeric(value), 0);
        case 'count': return Array.isArray(args[0]) ? args[0].length : args[0] == null ? 0 : 1;
        case 'concat': return args.map((value) => String(value ?? '')).join('');
        case 'min': return Math.min(...values.map(numeric));
        case 'max': return Math.max(...values.map(numeric));
        case 'round': { const digits = args.length > 1 ? numeric(args[1]) : 0; if (!Number.isInteger(digits) || digits < 0 || digits > 10) throw new Error('Round digits must be 0–10.'); return Number(numeric(args[0]).toFixed(digits)); }
      }
    }
    if (node.kind === 'binary') {
      const left = run(node.left), right = run(node.right);
      switch (node.value) {
        case '==': return left === right; case '!=': return left !== right;
        case '>': return numeric(left) > numeric(right); case '>=': return numeric(left) >= numeric(right);
        case '<': return numeric(left) < numeric(right); case '<=': return numeric(left) <= numeric(right);
        case '+': return numeric(left) + numeric(right); case '-': return numeric(left) - numeric(right); case '*': return numeric(left) * numeric(right);
        case '/': case '%': if (numeric(right) === 0) throw new Error('Division by zero.'); return node.value === '/' ? numeric(left) / numeric(right) : numeric(left) % numeric(right);
      }
    }
    throw new Error('Unsupported expression.');
  }
  return run(parseExpression(source));
}
export function matchesConditions(conditions: Condition[], data: Record<string, unknown>): boolean {
  return conditions.every(({ field, op, value }) => {
    const actual = readPath(data, field);
    switch (op) {
      case '==': return actual === value; case '!=': return actual !== value;
      case '>': return typeof actual === 'number' && typeof value === 'number' && actual > value;
      case '>=': return typeof actual === 'number' && typeof value === 'number' && actual >= value;
      case '<': return typeof actual === 'number' && typeof value === 'number' && actual < value;
      case '<=': return typeof actual === 'number' && typeof value === 'number' && actual <= value;
      case 'contains': return Array.isArray(actual) ? actual.includes(value) : typeof actual === 'string' && typeof value === 'string' && actual.includes(value);
      default: throw new Error(`Unknown condition operator: ${op}`);
    }
  });
}
export function validateWorkflow(workflow: Workflow): string[] {
  const errors: string[] = [];
  if (!workflow.name?.trim()) errors.push('Workflow name is required.');
  if (!['record.created', 'record.updated', 'record.deleted', 'schedule.cron', 'webhook.received'].includes(workflow.trigger?.type)) errors.push('Choose a supported trigger.');
  if (workflow.trigger?.type.startsWith('record.') && !validName(workflow.trigger.entity ?? '')) errors.push('Choose a trigger entity.');
  if (workflow.trigger?.type === 'schedule.cron' && !workflow.trigger.cron?.trim()) errors.push('Provide a schedule.');
  if (!Array.isArray(workflow.conditions)) errors.push('Conditions must be an array.');
  else for (const condition of workflow.conditions) if (!condition || typeof condition.field !== 'string' || condition.field.split('.').some((part) => !validName(part)) || !['==', '!=', '>', '>=', '<', '<=', 'contains'].includes(condition.op)) errors.push('Invalid workflow condition.');
  if (!Array.isArray(workflow.actions) || !workflow.actions.length) errors.push('Add at least one action.');
  else for (const action of workflow.actions) if (!['send_whatsapp', 'send_sms', 'send_email', 'create_record', 'update_record', 'call_webhook', 'assign_to_user'].includes(action.type)) errors.push(`Unsupported action: ${action.type}`);
  return errors;
}
