const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const path = require('node:path');
const ts = require('typescript');
const filename = path.resolve(__dirname, '../src/shop-store.ts');
const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } });
const moduleInstance = new Module(filename, module); moduleInstance._compile(compiled.outputText, filename);
const store = moduleInstance.exports;
function fixture(demo = true) {
  let state = store.emptyShop(demo, demo ? 'local-demo' : 'shop-1');
  state.shop.name = 'Test Shop';
  state = store.saveProduct(state, { name: 'Tea', price: 100, cost: 60, stock: 5, gst_rate: 18, barcode: '123' });
  state = store.saveCustomer(state, { name: 'Priya', phone: '9876543210' });
  return state;
}
test('a credit sale posts one atomic batch and repayment updates its ledger', () => {
  const before = fixture(false), product = before.products[0], customer = before.customers[0];
  const next = store.checkout(before, [{ product_id: product.id, quantity: 2 }], { mode: 'credit', customerId: customer.id, discount: 20 });
  assert.equal(next.invoices[0].total, 212.4); assert.equal(next.invoices[0].tax_amount, 32.4);
  assert.equal(next.products[0].stock, 3); assert.equal(next.customers[0].outstanding, 212.4);
  assert.equal(before.products[0].stock, 5); assert.equal(before.invoices.length, 0);
  const batch = next.outbox.at(-1); assert.ok(batch.mutations.some(m => m.entity === 'invoice'));
  assert.ok(batch.mutations.some(m => m.entity === 'product' && m.payload.delta === -2));
  const paid = store.receivePayment(next, customer.id, 12.4, 'cash');
  assert.equal(paid.customers[0].outstanding, 200); assert.equal(paid.records.ledger.length, 2);
  assert.throws(() => store.receivePayment(paid, customer.id, 201, 'cash'), /within the outstanding/);
});
test('insufficient stock, missing customers, invalid discounts, and duplicate lines cannot post', () => {
  const state = fixture(), id = state.products[0].id, cart = [{ product_id: id, quantity: 1 }];
  assert.throws(() => store.checkout(state, [{ product_id: id, quantity: 6 }], { mode: 'cash' }), /Only 5/);
  assert.throws(() => store.checkout(state, cart, { mode: 'credit' }), /Select a customer/);
  assert.throws(() => store.checkout(state, cart, { mode: 'cash', customerId: 'deleted' }), /no longer exists/);
  assert.throws(() => store.checkout(state, cart, { mode: 'cash', discount: 101 }), /cannot exceed/);
  assert.throws(() => store.checkout(state, [...cart, ...cart], { mode: 'cash' }), /Duplicate/);
  assert.equal(state.invoices.length, 0); assert.equal(state.products[0].stock, 5);
});
test('UPI and card sales and repayments require manual receipt confirmation', () => {
  const state = fixture(), cart = [{ product_id: state.products[0].id, quantity: 1 }];
  for (const mode of ['upi', 'card']) {
    assert.throws(() => store.checkout(state, cart, { mode }), /Confirm/);
    assert.equal(store.checkout(state, cart, { mode, confirmed: true }).invoices[0].total, 118);
  }
  const credit = store.checkout(state, cart, { mode: 'credit', customerId: state.customers[0].id });
  assert.throws(() => store.receivePayment(credit, state.customers[0].id, 10, 'upi'), /Confirm/);
});
test('GST is proportional to mixed-rate lines after a bill discount', () => {
  let state = fixture(); state = store.saveProduct(state, { name: 'Milk', price: 100, stock: 2, gst_rate: 0 });
  const totals = store.billTotals(state, state.products.map(p => ({ product_id: p.id, quantity: 1 })), 0, 10);
  assert.equal(totals.subtotal, 200); assert.equal(totals.discountAmount, 20); assert.equal(totals.tax, 16.2); assert.equal(totals.total, 196.2);
});
test('zero-value credit bills do not queue a zero balance adjustment', () => {
  const state = fixture(false), next = store.checkout(state, [{ product_id: state.products[0].id, quantity: 1 }], { mode: 'credit', customerId: state.customers[0].id, percent: 100 });
  assert.equal(next.invoices[0].total, 0); assert.equal(next.customers[0].outstanding, 0);
  assert.ok(!next.outbox.at(-1).mutations.some(m => m.entity === 'customer'));
});
test('cashiers can sell but cannot edit inventory, settings, or add prohibited stock records', () => {
  const state = { ...fixture(false), role: 'cashier' };
  assert.throws(() => store.saveProduct(state, { name: 'Hidden', stock: 1, price: 2 }), /role/);
  assert.throws(() => store.saveSettings(state, { name: 'Hidden' }), /role/);
  const sold = store.checkout(state, [{ product_id: state.products[0].id, quantity: 1 }], { mode: 'cash' });
  assert.ok(!sold.outbox.at(-1).mutations.some(m => m.entity === 'stock_adjustment'));
  assert.throws(() => store.checkout({ ...state, role: 'viewer' }, [{ product_id: state.products[0].id, quantity: 1 }], { mode: 'cash' }), /role/);
});
test('browser persistence rejects quota failures and conflicting tab revisions', () => {
  const before = fixture(), next = store.checkout(before, [{ product_id: before.products[0].id, quantity: 1 }], { mode: 'cash' });
  const storage = { getItem: () => JSON.stringify(before), setItem: () => { throw new Error('Quota exceeded'); } };
  assert.throws(() => store.persistState(before, next, storage), /Quota/); assert.equal(before.invoices.length, 0);
  assert.throws(() => store.persistState(before, next, { getItem: () => JSON.stringify(next), setItem() {} }), /another tab/);
});
test('invoices retain product snapshots after editing and deleting inventory', () => {
  const before = fixture(), p = before.products[0];
  let next = store.checkout(before, [{ product_id: p.id, quantity: 1 }], { mode: 'cash' });
  next = store.saveProduct(next, { ...next.products[0], name: 'New name', price: 250 }, p.id);
  next = store.deleteProduct(next, p.id); assert.equal(next.invoices[0].items[0].product.name, 'Tea'); assert.equal(next.invoices[0].total, 118);
});
test('negative prices, fractional stock, empty numbers and duplicate barcodes are rejected', () => {
  const state = fixture();
  for (const values of [{ price: -1 }, { stock: 1.5 }, { price: '' }, { gst_rate: 101 }, { cost: Infinity }]) assert.throws(() => store.saveProduct(state, { name: 'Test', price: 5, stock: 2, ...values }));
  assert.throws(() => store.saveProduct(state, { name: 'Test', price: 5, stock: 2, barcode: '123' }), /barcode/);
});
test('backup restores only validated local data belonging to this shop', () => {
  const state = fixture(), backup = JSON.stringify(state), restored = store.restoreBackup(state, backup);
  assert.equal(restored.revision, state.revision + 1); assert.equal(restored.products[0].name, 'Tea');
  assert.throws(() => store.restoreBackup({ ...state, demo: false }, backup), /Cloud backups/);
  assert.throws(() => store.restoreBackup({ ...state, tenantId: 'other' }, backup), /another shop/);
  assert.throws(() => store.restoreBackup(state, '{}'), /invalid/);
});
test('demo statistics and credit balances come from saved invoices', () => {
  const state = store.createDemo(new Date('2026-10-01T15:00:00+05:30')); store.validateState(state);
  assert.equal(state.invoices.length, 34); assert.equal(state.products.length, 12); assert.equal(state.outbox.length, 0);
  for (const customer of state.customers) assert.equal(customer.outstanding, store.round(state.invoices.filter(i => i.customer_id === customer.id && i.payment_mode === 'credit').reduce((sum, i) => sum + i.total, 0)));
  assert.equal(new Set(state.invoices.map(i => i.invoice_number)).size, state.invoices.length);
});
test('CSV exports escape quotes and spreadsheet formula prefixes', () => {
  const output = store.csv([['=1+1', 'Tea "Gold"', '+919876543210']]);
  assert.ok(output.includes("'=1+1")); assert.ok(output.includes('Tea ""Gold""')); assert.ok(output.includes("'+919876543210"));
});
