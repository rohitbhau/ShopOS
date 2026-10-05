import { test, expect } from '@playwright/test';

test('desktop shop: inventory, credit sale, repayment, invoice, and persistence', async ({ page }) => {
  const errors: string[] = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto('/'); await expect(page.getByRole('heading', { name: 'A good day starts here.' })).toBeVisible();
  await page.getByRole('button', { name: 'Products', exact: true }).click();
  await page.getByRole('button', { name: 'Add product', exact: true }).click();
  const productDialog = page.getByRole('dialog');
  await productDialog.getByLabel('Product name').fill('Test Tea'); await productDialog.getByLabel('Selling price').fill('100');
  await productDialog.getByLabel('Stock quantity').fill('8'); await productDialog.getByLabel('GST rate').selectOption('18');
  await productDialog.getByRole('button', { name: 'Add product' }).click(); await expect(page.getByText('Test Tea', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Customers', exact: true }).click(); await page.getByRole('button', { name: 'Add customer', exact: true }).click();
  await page.getByRole('dialog').getByLabel('Customer name').fill('Test Customer'); await page.getByRole('dialog').getByLabel('Mobile number').fill('9876543255');
  await page.getByRole('dialog').getByRole('button', { name: 'Add customer' }).click();
  await page.getByRole('button', { name: 'Point of sale', exact: true }).click();
  await page.getByRole('textbox', { name: 'Search a product or scan barcode' }).fill('Test Tea');
  await page.getByRole('button', { name: /General Test Tea/ }).click();
  await page.getByLabel('Sale customer').selectOption({ label: 'Test Customer' }); await page.getByRole('button', { name: 'Credit', exact: true }).click();
  await page.getByRole('button', { name: 'Complete sale' }).click();
  await expect(page.getByRole('dialog').getByText('₹118.00', { exact: true })).toBeVisible();
  await expect(page.locator('#shopos-receipt')).toContainText('Test Customer');
  await page.getByRole('button', { name: 'Done', exact: true }).click();
  await page.getByRole('button', { name: 'Customers', exact: true }).click();
  const row = page.getByRole('row').filter({ hasText: 'Test Customer' }); await expect(row).toContainText('₹118.00');
  await row.getByRole('button', { name: 'Record payment' }).click();
  await page.getByRole('dialog').getByLabel('Amount received').fill('18'); await page.getByRole('dialog').getByRole('button', { name: 'Record payment' }).click();
  await expect(row).toContainText('₹100.00'); await page.reload(); await page.getByRole('button', { name: 'Customers', exact: true }).click();
  await expect(page.getByRole('row').filter({ hasText: 'Test Customer' })).toContainText('₹100.00');
  await page.getByRole('button', { name: 'Products', exact: true }).click(); await expect(page.getByRole('row').filter({ hasText: 'Test Tea' })).toContainText('7 units');
  await page.getByRole('button', { name: 'Overview', exact: true }).click(); await page.screenshot({ path: 'test-results/shopos-desktop.png', fullPage: true });
  expect(errors).toEqual([]);
});
test('payment confirmation and stock limits prevent accidental sales', async ({ page }) => {
  await page.goto('/'); await page.getByRole('button', { name: 'Point of sale', exact: true }).click();
  await page.getByRole('textbox', { name: 'Search a product or scan barcode' }).fill('Sunflower');
  await page.getByRole('button', { name: /Sunflower Oil/ }).click(); await page.getByRole('button', { name: 'UPI', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Complete sale' })).toBeDisabled();
  await page.getByRole('checkbox', { name: 'I verified that payment was received.' }).check(); await expect(page.getByRole('button', { name: 'Complete sale' })).toBeEnabled();
  for (let i = 0; i < 3; i++) await page.getByRole('button', { name: 'Increase Sunflower Oil' }).click();
  await expect(page.getByRole('button', { name: 'Increase Sunflower Oil' })).toBeDisabled();
  await page.getByLabel('Bill discount amount').fill('9999'); await expect(page.getByRole('button', { name: 'Complete sale' })).toBeDisabled();
  await expect(page.getByRole('alert').filter({ hasText: 'Discount cannot exceed' })).toBeVisible();
});
for (const width of [390, 768]) test(`responsive workspace at ${width}px supports navigation and checkout`, async ({ page }) => {
  await page.setViewportSize({ width, height: 844 }); const errors: string[] = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto('/'); await expect(page.getByRole('heading', { name: 'A good day starts here.' })).toBeVisible();
  const overflow = await page.evaluate(() => Array.from(document.querySelectorAll('main *')).filter(element => element.getBoundingClientRect().right > window.innerWidth + 1 && getComputedStyle(element).position !== 'fixed').map(element => ({ tag: element.tagName, className: element.className, right: element.getBoundingClientRect().right })).slice(0, 12));
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), JSON.stringify(overflow)).toBe(true);
  await page.screenshot({ path: `test-results/shopos-${width}.png`, fullPage: true });
  if (width < 760) await page.getByRole('button', { name: 'Open navigation' }).click();
  await page.getByRole('button', { name: 'Point of sale', exact: true }).click(); await page.getByRole('button', { name: /Basmati Rice/ }).click();
  await page.getByRole('button', { name: 'Complete sale' }).click(); await expect(page.locator('#shopos-receipt')).toBeVisible();
  await page.getByRole('button', { name: 'Close dialog' }).click(); expect(errors).toEqual([]);
});
test('administration remains reachable and opens the local demo', async ({ page }) => {
  await page.goto('/admin'); await page.getByRole('button', { name: 'Open local demo' }).click();
  await expect(page.getByRole('heading', { name: 'Overview', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Low-code builder', exact: true }).click(); await expect(page.getByLabel('Entity key')).toHaveValue('product');
});
test('shop API rejects unauthenticated writes and missing origins', async ({ request }) => {
  const noOrigin = await request.post('/api/shop/sync', { data: { tenantId: 'other', mutations: [] } }); expect(noOrigin.status()).toBe(403);
  const signedOut = await request.post('/api/shop/sync', { headers: { Origin: 'http://127.0.0.1:3000' }, data: { tenantId: 'other', mutations: [] } }); expect(signedOut.status()).toBe(401);
});
test('the saved demo can reopen after the network goes offline', async ({ page, context }) => {
  await page.goto('/'); await expect(page.getByRole('heading', { name: 'A good day starts here.' })).toBeVisible();
  await page.evaluate(async () => { await navigator.serviceWorker.ready; if (!navigator.serviceWorker.controller) await new Promise<void>(resolve => navigator.serviceWorker.addEventListener('controllerchange', () => resolve(), { once: true })); });
  await context.setOffline(true); await page.reload(); await expect(page.getByRole('heading', { name: 'A good day starts here.' })).toBeVisible();
  await page.getByRole('button', { name: 'Products', exact: true }).click(); await expect(page.getByRole('row').filter({ hasText: 'Basmati Rice' })).toBeVisible();
});
