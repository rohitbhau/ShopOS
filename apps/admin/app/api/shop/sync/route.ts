import { NextRequest } from 'next/server';
import { ApiError, requireOrigin, supabase } from '../../../../src/server';
import { checked, shopError, shopResponse, shopSession } from '../../../../src/shop-server';
import type { Mutation } from '../../../../src/shop-store';

export const dynamic = 'force-dynamic';
export async function POST(request: NextRequest) {
  try {
    requireOrigin(request); const auth = await shopSession();
    const body = await request.json(), tenantId = auth.user.app_metadata?.tenant_id;
    if (!tenantId || body.tenantId !== tenantId) throw new ApiError('The queued changes belong to another shop.', 403);
    if (!Array.isArray(body.mutations) || body.mutations.length < 1 || body.mutations.length > 500 || JSON.stringify(body).length > 5242880) throw new ApiError('Invalid sync batch.');
    const mutations = body.mutations as Mutation[];
    for (const mutation of mutations.filter(m => m.entity === '_tenant')) {
      if (auth.user.app_metadata?.shop_role !== 'owner') throw new ApiError('Only the owner can change shop settings.', 403);
      if (!mutation.payload || mutation.payload.id !== tenantId) throw new ApiError('Invalid shop profile update.', 403);
      const { name, phone, gstin, address, tagline, city, state, pincode, whatsapp, business_type } = mutation.payload;
      await checked(await supabase(`/rest/v1/tenants?id=eq.${encodeURIComponent(tenantId)}`, {
        method: 'PATCH',
        body: JSON.stringify({ name, phone, gstin, address, tagline, city, state, pincode, whatsapp, business_type })
      }, auth.token));
    }
    const records = mutations.filter(m => m.entity !== '_tenant');
    if (records.length) await checked(await supabase('/rest/v1/rpc/sync_mutations', { method: 'POST', body: JSON.stringify({ p_mutations: records }) }, auth.token));
    return shopResponse({ ok: true }, auth);
  } catch (error) { return shopError(error); }
}
