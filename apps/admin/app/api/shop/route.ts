import { NextRequest } from 'next/server';
import { ApiError, requireOrigin, supabase } from '../../../src/server';
import { checked, refreshShopClaims, shopError, shopResponse, shopSession } from '../../../src/shop-server';

export const dynamic = 'force-dynamic';
export async function GET() {
  try {
    const { auth, tenantId } = await refreshShopClaims(await shopSession());
    if (!tenantId) return shopResponse({ user: auth.user, needsShop: true }, auth);
    const tenants = await checked(await supabase(`/rest/v1/tenants?id=eq.${encodeURIComponent(tenantId)}&select=*`, {}, auth.token));
    if (!tenants[0]) throw new ApiError('Your shop is unavailable or access was removed.', 403);
    const apps = await checked(await supabase(`/rest/v1/apps?tenant_id=eq.${encodeURIComponent(tenantId)}&select=id,template_key&is_active=eq.true`, {}, auth.token));
    const schemas: Record<string, unknown> = {};
    for (const app of apps) {
      const entities = await checked(await supabase(`/rest/v1/entities?app_id=eq.${encodeURIComponent(app.id)}&select=name,label,schema`, {}, auth.token));
      for (const entity of entities) schemas[entity.name] = { ...entity.schema, label: entity.label };
    }
    const records: unknown[] = []; let since: string | null = null, afterId: string | null = null;
    while (true) {
      const rows = await checked(await supabase('/rest/v1/rpc/pull_records', { method: 'POST', body: JSON.stringify({ p_since: since, p_after_id: afterId, p_limit: 500 }) }, auth.token));
      records.push(...rows);
      if (rows.length < 500) break;
      since = rows[rows.length - 1].updated_at; afterId = rows[rows.length - 1].id;
    }
    return shopResponse({ user: auth.user, tenant: { ...tenants[0], template_key: apps[0]?.template_key }, schemas, records }, auth);
  } catch (error) { return shopError(error); }
}
export async function POST(request: NextRequest) {
  try {
    requireOrigin(request); const auth = await shopSession(), body = await request.json();
    if (body.action !== 'create_shop') throw new ApiError('Unknown shop action.');
    const name = String(body.name || '').trim();
    if (!name || name.length > 100) throw new ApiError('Enter a shop name (up to 100 characters).');
    const VALID_TEMPLATES = ['retail_basic', 'boutique', 'restaurant', 'pharmacy', 'salon', 'repair'];
    const template = VALID_TEMPLATES.includes(String(body.template)) ? String(body.template) : 'retail_basic';
    const business_type = String(body.business_type || template);
    await checked(await supabase('/functions/v1/create-tenant', { method: 'POST', body: JSON.stringify({
      name,
      template_key: template,
      shop_type: template === 'retail_basic' ? 'retail' : template,
      business_type,
      phone: auth.user.phone,
      address: { text: String(body.address || '') },
      gstin: body.gstin || null,
      tagline: body.tagline || null,
      city: body.city || null,
      state: body.state || null,
      pincode: body.pincode || null,
      whatsapp: body.whatsapp || null,
    }) }, auth.token));
    const refreshed = await refreshShopClaims(auth); return shopResponse({ ok: true }, refreshed.auth);
  } catch (error) { return shopError(error); }
}
