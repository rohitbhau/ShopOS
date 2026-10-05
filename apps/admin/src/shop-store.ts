export type Role = 'owner' | 'manager' | 'cashier' | 'viewer';
export type PaymentMode = 'cash' | 'upi' | 'card' | 'credit';
export type Product = { id: string; name: string; price: number; cost: number; stock: number; gst_rate: number; category: string; barcode: string; min_stock: number; [key: string]: unknown };
export type Customer = { id: string; name: string; phone: string; address: string; outstanding: number; [key: string]: unknown };
export type CartItem = { product_id: string; quantity: number };
export type InvoiceLine = { product: Product; quantity: number; gst_rate: number; total: number };
export type Invoice = { id: string; invoice_number: string; created_at: string; invoice_date: string; items: InvoiceLine[]; subtotal: number; discount_amount: number; tax_amount: number; total: number; payment_mode: PaymentMode; payment_status: string; customer_id?: string; customer_name?: string };
export type Field = { name: string; type: string; label?: string; required?: boolean; options?: unknown[]; min?: number; max?: number; default?: unknown; [key: string]: unknown };
export type Schema = { label: string; fields: Field[] };
export type ShopRecord = { id: string; created_at: string; [key: string]: unknown };
export type Mutation = { id: string; entity: string; action: string; payload: Record<string, unknown> };
export type Batch = { id: string; mutations: Mutation[]; created_at: string };
export type BusinessType = 'retail' | 'restaurant' | 'pharmacy' | 'boutique' | 'salon' | 'repair' | 'grocery' | 'electronics' | 'hardware' | 'medical' | 'bakery' | 'other';
export type ShopState = {
  version: 1; revision: number; tenantId: string; userId?: string; demo: boolean; role: Role; device: string; sequence: number;
  shop: { name: string; address: string; phone: string; gstin: string; upi_id: string; template: string; plan: string; paper: string; logo?: string; business_type?: BusinessType; city?: string; state?: string; pincode?: string; whatsapp?: string; tagline?: string };
  products: Product[]; customers: Customer[]; invoices: Invoice[]; records: Record<string, ShopRecord[]>; schemas: Record<string, Schema>; outbox: Batch[];
};
export const round = (amount: number) => Math.round((amount + Number.EPSILON) * 100) / 100;
export const money = (amount: number) => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 }).format(amount);
export const uid = () => globalThis.crypto.randomUUID();
export function can(role: Role, permission: 'manage' | 'sell' | 'reports' | 'settings') {
  if (permission === 'settings') return role === 'owner';
  if (permission === 'reports') return ['owner', 'manager'].includes(role);
  if (permission === 'sell') return role !== 'viewer';
  return ['owner', 'manager'].includes(role); // manage
}
function requirePermission(state: ShopState, permission: Parameters<typeof can>[1]) {
  if (!can(state.role, permission)) throw new Error('Your shop role does not allow this action.');
}
function numeric(value: unknown, label: string, max = 1000000000) {
  if (value === '' || value === null || value === undefined || typeof value === 'boolean') throw new Error(`${label} is required.`);
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0 || amount > max) throw new Error(`${label} must be a valid positive number or zero.`);
  return amount;
}
function whole(value: unknown, label: string) {
  const amount = numeric(value, label);
  if (!Number.isInteger(amount)) throw new Error(`${label} must be a whole number.`);
  return amount;
}
function required(value: unknown, label: string) {
  const text = String(value ?? '').trim();
  if (!text || text.length > 200) throw new Error(`Enter a ${label.toLowerCase()} (up to 200 characters).`);
  return text;
}
export function emptyShop(demo = true, tenantId = 'local-demo', role: Role = 'owner'): ShopState {
  return { version: 1, revision: 0, tenantId, demo, role, device: uid().replaceAll('-', '').slice(0, 12).toUpperCase(), sequence: 0,
    shop: { name: '', address: '', phone: '', gstin: '', upi_id: '', template: 'retail_basic', plan: 'free', paper: 'a4', logo: '', business_type: 'retail', city: '', state: '', pincode: '', whatsapp: '', tagline: '' },
    products: [], customers: [], invoices: [], records: {}, schemas: {}, outbox: [] };
}
function transaction(state: ShopState, update: (next: ShopState, mutations: Mutation[]) => void): ShopState {
  const next = structuredClone(state), mutations: Mutation[] = [];
  update(next, mutations);
  next.revision++;
  if (!next.demo && mutations.length) next.outbox.push({ id: uid(), mutations, created_at: new Date().toISOString() });
  return next;
}
function mutate(list: Mutation[], entity: string, action: string, payload: Record<string, unknown>) {
  list.push({ id: uid(), entity, action, payload: { ...payload, updated_at: new Date().toISOString() } });
}
function record(state: ShopState, mutations: Mutation[], entity: string, values: Record<string, unknown>) {
  const item = { ...values, id: String(values.id || uid()), created_at: String(values.created_at || new Date().toISOString()) };
  const list = state.records[entity] ?? [];
  const exists = list.some(row => row.id === item.id);
  state.records[entity] = [...list.filter(row => row.id !== item.id), item];
  mutate(mutations, entity, exists ? 'update' : 'create', item);
}
export function saveProduct(state: ShopState, values: Record<string, unknown>, id?: string) {
  requirePermission(state, 'manage');
  return transaction(state, (next, changes) => {
    const existing = id ? next.products.find(p => p.id === id) : undefined;
    if (id && !existing) throw new Error('This product was removed. Refresh the inventory.');
    const product: Product = { ...existing, ...values, id: id || uid(), name: required(values.name, 'Product name'),
      price: round(numeric(values.price, 'Price')), cost: round(numeric(values.cost ?? 0, 'Cost')),
      stock: whole(values.stock, 'Stock'), gst_rate: numeric(values.gst_rate ?? 0, 'GST rate', 100),
      category: String(values.category || 'General').trim(), barcode: String(values.barcode || '').trim(), min_stock: whole(values.min_stock ?? 5, 'Low stock threshold') };
    if (product.barcode && next.products.some(p => p.id !== id && p.barcode === product.barcode)) throw new Error('This barcode already belongs to another product.');
    product.gst = product.gst_rate; product.low_stock_threshold = product.min_stock;
    next.products = [...next.products.filter(p => p.id !== id), product];
    mutate(changes, 'product', existing ? 'update' : 'create', product);
    if (existing && existing.stock !== product.stock) record(next, changes, 'stock_adjustment', { product_id: product.id, delta: product.stock - existing.stock, reason: 'Inventory adjustment' });
  });
}
export function deleteProduct(state: ShopState, id: string) {
  requirePermission(state, 'manage');
  return transaction(state, (next, changes) => {
    if (!next.products.some(p => p.id === id)) throw new Error('Product no longer exists.');
    next.products = next.products.filter(p => p.id !== id); mutate(changes, 'product', 'delete', { id });
  });
}
export function saveCustomer(state: ShopState, values: Record<string, unknown>, id?: string) {
  requirePermission(state, 'sell');
  return transaction(state, (next, changes) => {
    const existing = id ? next.customers.find(c => c.id === id) : undefined;
    if (id && !existing) throw new Error('Customer no longer exists.');
    const phone = String(values.phone ?? '').replace(/[\s-]/g, '');
    if (phone && !/^(\+91)?[6-9]\d{9}$/.test(phone)) throw new Error('Enter a valid 10-digit Indian mobile number.');
    const customer: Customer = { ...existing, id: id || uid(), name: required(values.name, 'Customer name'), phone,
      address: String(values.address || ''), outstanding: existing?.outstanding ?? 0 };
    next.customers = [...next.customers.filter(c => c.id !== id), customer];
    mutate(changes, 'customer', existing ? 'update' : 'create', customer);
  });
}
export function billTotals(state: ShopState, cart: CartItem[], discount = 0, percent = 0) {
  const lines: InvoiceLine[] = cart.map(item => {
    const product = state.products.find(p => p.id === item.product_id);
    if (!product) throw new Error('A product in this bill was removed.');
    if (!Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > product.stock) throw new Error(`Only ${product.stock} ${product.name} available.`);
    return { product: structuredClone(product), quantity: item.quantity, gst_rate: product.gst_rate, total: round(product.price * item.quantity) };
  });
  if (new Set(cart.map(item => item.product_id)).size !== cart.length) throw new Error('Duplicate product lines are not allowed.');
  const subtotal = round(lines.reduce((sum, line) => sum + line.total, 0));
  const discountAmount = round(numeric(discount, 'Discount') + subtotal * numeric(percent, 'Discount percent', 100) / 100);
  if (discountAmount > subtotal) throw new Error('Discount cannot exceed the subtotal.');
  const taxable = round(subtotal - discountAmount);
  const tax = round(lines.reduce((sum, line) => sum + (subtotal === 0 ? 0 : line.total * taxable / subtotal * line.gst_rate / 100), 0));
  return { lines, subtotal, discountAmount, tax, total: round(taxable + tax) };
}
export function checkout(state: ShopState, cart: CartItem[], options: { mode: PaymentMode; customerId?: string; discount?: number; percent?: number; confirmed?: boolean; now?: Date }) {
  requirePermission(state, 'sell');
  return transaction(state, (next, changes) => {
    if (!cart.length) throw new Error('Add at least one product to the bill.');
    if (!['cash', 'upi', 'card', 'credit'].includes(options.mode)) throw new Error('Choose a valid payment method.');
    if (['upi', 'card'].includes(options.mode) && !options.confirmed) throw new Error('Confirm that payment was received before completing the sale.');
    const customer = next.customers.find(c => c.id === options.customerId);
    if (options.customerId && !customer) throw new Error('Selected customer no longer exists.');
    if (options.mode === 'credit' && !customer) throw new Error('Select a customer for a credit sale.');
    const totals = billTotals(next, cart, options.discount ?? 0, options.percent ?? 0), now = options.now ?? new Date();
    const date = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' }).replaceAll('-', '');
    const invoice: Invoice = { id: uid(), invoice_number: `${next.device}-${date}-${String(++next.sequence).padStart(4, '0')}`,
      created_at: now.toISOString(), invoice_date: now.toISOString(), items: totals.lines, subtotal: totals.subtotal,
      discount_amount: totals.discountAmount, tax_amount: totals.tax, total: totals.total, payment_mode: options.mode,
      payment_status: options.mode === 'credit' ? 'pending' : 'paid', customer_id: customer?.id, customer_name: customer?.name };
    next.invoices.unshift(invoice); mutate(changes, 'invoice', 'create', invoice);
    for (const line of totals.lines) {
      next.products.find(p => p.id === line.product.id)!.stock -= line.quantity;
      mutate(changes, 'product', 'adjust', { id: line.product.id, field: 'stock', delta: -line.quantity });
      if (next.role !== 'cashier') record(next, changes, 'stock_adjustment', { product_id: line.product.id, delta: -line.quantity, reason: 'Sale', invoice_id: invoice.id });
    }
    if (options.mode === 'credit' && customer && invoice.total > 0) {
      customer.outstanding = round(customer.outstanding + invoice.total);
      mutate(changes, 'customer', 'adjust', { id: customer.id, field: 'outstanding', delta: invoice.total });
      record(next, changes, 'ledger', { customer_id: customer.id, invoice_id: invoice.id, amount: invoice.total, type: 'credit_sale', created_at: now.toISOString() });
    }
  });
}
export function receivePayment(state: ShopState, customerId: string, amount: number, mode: PaymentMode, confirmed = false) {
  requirePermission(state, 'sell');
  return transaction(state, (next, changes) => {
    const customer = next.customers.find(c => c.id === customerId), payment = round(numeric(amount, 'Payment'));
    if (!customer || payment <= 0 || payment > customer.outstanding) throw new Error('Payment must be greater than zero and within the outstanding balance.');
    if (!['cash', 'upi', 'card'].includes(mode)) throw new Error('Choose cash, UPI, or card.');
    if (mode !== 'cash' && !confirmed) throw new Error('Confirm that the customer payment was received.');
    customer.outstanding = round(customer.outstanding - payment);
    mutate(changes, 'customer', 'adjust', { id: customer.id, field: 'outstanding', delta: -payment });
    record(next, changes, 'ledger', { customer_id: customer.id, amount: payment, type: 'payment_received', payment_mode: mode });
  });
}
export function saveSettings(state: ShopState, values: Record<string, unknown>) {
  requirePermission(state, 'settings');
  return transaction(state, (next, changes) => {
    // Preserve logo (not a form field) and merge all new fields
    next.shop = {
      ...next.shop,
      name: required(values.name, 'Shop name'),
      address: String(values.address || ''),
      phone: String(values.phone || ''),
      gstin: String(values.gstin || ''),
      upi_id: String(values.upi_id || ''),
      paper: String(values.paper || 'a4'),
      tagline: String(values.tagline || ''),
      city: String(values.city || ''),
      state: String(values.state || ''),
      pincode: String(values.pincode || ''),
      whatsapp: String(values.whatsapp || ''),
      business_type: (values.business_type as BusinessType) || next.shop.business_type || 'retail',
    };
    if (next.shop.upi_id && !/^[\w.\-]+@[\w.\-]+$/.test(next.shop.upi_id)) throw new Error('Enter a valid UPI ID, such as yourshop@upi.');
    if (next.shop.gstin && !/^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(next.shop.gstin)) throw new Error('Enter a valid 15-character GSTIN.');
    if (next.shop.pincode && !/^[1-9][0-9]{5}$/.test(next.shop.pincode)) throw new Error('Enter a valid 6-digit PIN code.');
    if (next.shop.whatsapp) {
      const w = next.shop.whatsapp.replace(/[\s-]/g, '');
      if (!/^(\+91)?[6-9]\d{9}$/.test(w)) throw new Error('Enter a valid WhatsApp number.');
      next.shop.whatsapp = w;
    }
    mutate(changes, '_tenant', 'update', {
      id: next.tenantId,
      name: next.shop.name,
      phone: next.shop.phone,
      gstin: next.shop.gstin || null,
      address: { text: next.shop.address, upi_id: next.shop.upi_id },
      tagline: next.shop.tagline || null,
      city: next.shop.city || null,
      state: next.shop.state || null,
      pincode: next.shop.pincode || null,
      whatsapp: next.shop.whatsapp || null,
      business_type: next.shop.business_type || null,
    });
  });
}
export function saveModule(state: ShopState, entity: string, values: Record<string, unknown>, id?: string) {
  requirePermission(state, 'manage');
  if (['product', 'customer', 'invoice', 'ledger', 'stock_adjustment'].includes(entity) || !state.schemas[entity]) throw new Error('Use the dedicated screen for this record.');
  return transaction(state, (next, changes) => {
    const schema = state.schemas[entity], parsed = { ...values };
    for (const field of schema.fields) {
      const value = parsed[field.name];
      if (field.required && (value === '' || value === undefined || value === null)) throw new Error(`${field.label || field.name} is required.`);
      if (value === '' || value === undefined || value === null) continue;
      if (['number', 'decimal'].includes(field.type)) {
        const n = Number(value);
        if (!Number.isFinite(n) || (field.min !== undefined && n < field.min) || (field.max !== undefined && n > field.max)) throw new Error(`Invalid ${field.label || field.name}.`);
        parsed[field.name] = n;
      }
      if (field.type === 'select' && !field.options?.includes(value)) throw new Error(`Select a valid ${field.label || field.name}.`);
    }
    record(next, changes, entity, { ...parsed, ...(id ? { id } : {}) });
  });
}
export const storageKey = (state: Pick<ShopState, 'demo' | 'tenantId' | 'userId'>) => state.demo ? 'shopos:shop:demo:v1' : `shopos:shop:${state.userId}:${state.tenantId}:v1`;
export function validateState(value: unknown): asserts value is ShopState {
  const s = value as ShopState;
  if (!s || s.version !== 1 || !s.shop || typeof s.shop.name !== 'string' || !Number.isInteger(s.revision) || !s.tenantId ||
    !Array.isArray(s.products) || !Array.isArray(s.customers) || !Array.isArray(s.invoices) || !Array.isArray(s.outbox) || !s.records || !s.schemas || !['owner', 'manager', 'cashier', 'viewer'].includes(s.role)) throw new Error('This shop backup or browser data is invalid.');
  // Backfill new optional fields so old saved states don't crash
  s.shop.logo ??= ''; s.shop.business_type ??= 'retail'; s.shop.city ??= ''; s.shop.state ??= '';
  s.shop.pincode ??= ''; s.shop.whatsapp ??= ''; s.shop.tagline ??= '';
  for (const p of s.products) { required(p.name, 'Product name'); numeric(p.price, 'Price'); whole(p.stock, 'Stock'); numeric(p.gst_rate, 'GST', 100); }
  for (const c of s.customers) { required(c.name, 'Customer name'); numeric(c.outstanding, 'Balance'); }
  for (const i of s.invoices) { if (!i.id || !i.invoice_number || !Array.isArray(i.items) || !Number.isFinite(Date.parse(i.created_at))) throw new Error('Invalid invoice in backup.'); numeric(i.total, 'Invoice total'); }
}
export function persistState(previous: ShopState, next: ShopState, storage: Pick<Storage, 'getItem' | 'setItem'> = localStorage) {
  const key = storageKey(previous), current = storage.getItem(key);
  if (current && (JSON.parse(current) as ShopState).revision !== previous.revision) throw new Error('Your shop was updated in another tab. Reload the page to continue.');
  storage.setItem(key, JSON.stringify(next));
}
export function restoreBackup(state: ShopState, source: string) {
  if (!state.demo) throw new Error('Cloud backups are exports. Restore through your shop administrator.');
  const parsed: unknown = JSON.parse(source); validateState(parsed);
  if (!parsed.demo || parsed.tenantId !== state.tenantId) throw new Error('This backup belongs to another shop.');
  return { ...parsed, revision: state.revision + 1, outbox: [] };
}
export function createDemo(now = new Date()): ShopState {
  let state = emptyShop();
  state.shop = { name: 'Maya General Store', address: '12, Market Road, Bengaluru', phone: '9876543210', gstin: '', upi_id: 'mayastore@upi', template: 'retail_basic', plan: 'free', paper: 'a4', logo: '', business_type: 'grocery', city: 'Bengaluru', state: 'Karnataka', pincode: '560001', whatsapp: '9876543210', tagline: 'Fresh & affordable, every day' };
  const samples = [
    ['Basmati Rice', 120, 88, 86, 5, 'Grains & staples', '890100100001'], ['Sunflower Oil', 145, 112, 42, 5, 'Cooking essentials', '890100100002'],
    ['Whole Wheat Atta', 65, 48, 95, 5, 'Grains & staples', '890100100003'], ['Tata Tea Gold', 135, 104, 70, 5, 'Beverages', '890100100004'],
    ['Amul Butter', 58, 46, 48, 12, 'Dairy', '890100100005'], ['Fresh Milk', 32, 26, 38, 0, 'Dairy', '890100100006'],
    ['Organic Toor Dal', 165, 126, 72, 5, 'Grains & staples', '890100100007'], ['Parle-G Biscuits', 20, 15, 125, 18, 'Snacks', '890100100008'],
    ['Dove Bath Soap', 55, 40, 35, 18, 'Personal care', '890100100009'], ['Filter Coffee', 180, 138, 65, 5, 'Beverages', '890100100010'],
    ['Rock Salt', 28, 18, 25, 0, 'Cooking essentials', '890100100011'], ['Maggi Noodles', 28, 20, 80, 12, 'Snacks', '890100100012'],
  ];
  for (const [name, price, cost, stock, gst_rate, category, barcode] of samples) state = saveProduct(state, { name, price, cost, stock, gst_rate, category, barcode, min_stock: 5 });
  for (const [name, phone] of [['Priya Sharma', '9876543211'], ['Rahul Mehta', '9876543212'], ['Anjali Patel', '9876543213'], ['Vikram Singh', '9876543214']]) state = saveCustomer(state, { name, phone, address: 'Bengaluru' });
  for (let day = 6; day >= 0; day--) for (let sale = 0; sale < 4 + (6 - day) % 3; sale++) {
    const time = new Date(now); time.setDate(time.getDate() - day); time.setHours(9 + sale, 15 + sale * 4, 0, 0);
    const a = state.products[(sale + day) % 12], b = state.products[(sale * 2 + day + 3) % 12];
    const cart = [{ product_id: a.id, quantity: sale % 2 + 1 }];
    if (a.id !== b.id) cart.push({ product_id: b.id, quantity: 2 });
    state = checkout(state, cart, { mode: sale === 2 ? 'credit' : sale % 2 ? 'upi' : 'cash', customerId: state.customers[sale % 4].id, confirmed: true, now: time });
  }
  state.products[1].stock = 4; state.products[4].stock = 3; state.products[8].stock = 0;
  state.schemas['supplier'] = { label: 'Suppliers', fields: [{ name: 'name', type: 'text', label: 'Supplier name', required: true }, { name: 'phone', type: 'text', label: 'Phone' }, { name: 'category', type: 'text', label: 'Supplies' }] };
  state.records.supplier = [{ id: uid(), name: 'Green Valley Distributors', phone: '9876543220', category: 'Grains & staples', created_at: now.toISOString() }];
  return state;
}
export function dayKey(date: string | Date) { return new Date(date).toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' }); }
export function periodInvoices(state: ShopState, days: number, now = new Date()) {
  if (days === 1) {
    const today = dayKey(now);
    return state.invoices.filter(i => dayKey(i.created_at) === today);
  }
  const start = new Date(now); start.setDate(start.getDate() - days + 1);
  const first = dayKey(start), last = dayKey(now);
  return state.invoices.filter(i => dayKey(i.created_at) >= first && dayKey(i.created_at) <= last);
}
export function csv(rows: unknown[][]) { return '\uFEFF' + rows.map(row => row.map(cell => `"${String(cell ?? '').replaceAll('"', '""').replace(/^[=+@-]/, "'$&")}"`).join(',')).join('\r\n'); }
