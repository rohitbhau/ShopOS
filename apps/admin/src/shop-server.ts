import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { ApiError, supabase } from './server';

export type ShopUser = { id: string; phone?: string; app_metadata?: { tenant_id?: string; shop_role?: string } };
export type ShopTokens = { access_token: string; refresh_token: string; expires_in: number; user: ShopUser };
export type ShopAuth = { token: string; user: ShopUser; refreshed?: ShopTokens };
export function setShopTokens(response: NextResponse, tokens: ShopTokens) {
  const options = { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict' as const, path: '/' };
  response.cookies.set('shopos_shop_access', tokens.access_token, { ...options, maxAge: tokens.expires_in });
  response.cookies.set('shopos_shop_refresh', tokens.refresh_token, { ...options, maxAge: 60 * 60 * 24 * 7 });
}
export function clearShopTokens(response: NextResponse) { response.cookies.delete('shopos_shop_access'); response.cookies.delete('shopos_shop_refresh'); }
export async function checked(response: Response) {
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new ApiError(data.msg || data.message || data.error_description || data.error || 'Shop service is unavailable.', response.status);
  return data;
}
export async function shopSession(): Promise<ShopAuth> {
  const jar = await cookies(), token = jar.get('shopos_shop_access')?.value;
  if (token) {
    const response = await supabase('/auth/v1/user', {}, token);
    if (response.ok) return { token, user: await response.json() };
    if (response.status >= 500) throw new ApiError('Authentication is temporarily unavailable.', 503);
  }
  const refresh = jar.get('shopos_shop_refresh')?.value;
  if (!refresh) throw new ApiError('Sign in to your shop to continue.', 401);
  const tokens = await checked(await supabase('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: JSON.stringify({ refresh_token: refresh }) })) as ShopTokens;
  return { token: tokens.access_token, user: tokens.user, refreshed: tokens };
}
export async function refreshShopClaims(auth: ShopAuth) {
  const claim = await checked(await supabase('/functions/v1/auth-set-tenant-claim', { method: 'POST', body: JSON.stringify({ ...(auth.user.app_metadata?.tenant_id ? { tenant_id: auth.user.app_metadata.tenant_id } : {}) }) }, auth.token));
  const refresh = auth.refreshed?.refresh_token || (await cookies()).get('shopos_shop_refresh')?.value;
  if (!refresh) throw new ApiError('Sign in again to load your shop.', 401);
  const tokens = await checked(await supabase('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: JSON.stringify({ refresh_token: refresh }) })) as ShopTokens;
  return { auth: { token: tokens.access_token, user: tokens.user, refreshed: tokens }, tenantId: claim.claims?.tenant_id as string | undefined };
}
export function shopResponse(data: unknown, auth?: ShopAuth) {
  const response = NextResponse.json(data); response.headers.set('Cache-Control', 'no-store');
  if (auth?.refreshed) setShopTokens(response, auth.refreshed);
  return response;
}
export function shopError(error: unknown) {
  const status = error instanceof ApiError ? error.status : 502;
  const response = NextResponse.json({ error: error instanceof ApiError ? error.message : 'Could not connect to your shop. Saved changes remain on this device.' }, { status });
  response.headers.set('Cache-Control', 'no-store');
  if (status === 401) clearShopTokens(response);
  return response;
}
