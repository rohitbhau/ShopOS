import { cookies } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';

type AuthUser = { id: string; email?: string; app_metadata?: { role?: string; super_admin?: boolean } };
type Tokens = { access_token: string; refresh_token: string; expires_in: number; user: AuthUser };
export class ApiError extends Error { constructor(message: string, public status = 400) { super(message); } }
export function configuration() {
  const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  return { url, key, mode: !url && !key ? 'demo' as const : url && key ? 'live' as const : 'incomplete' as const };
}
export function requireOrigin(request: NextRequest) {
  const origin = request.headers.get('origin');
  const expected = process.env.ADMIN_ORIGIN || request.nextUrl.origin;
  if (!origin || origin !== expected) throw new ApiError('Request origin rejected.', 403);
}
export async function supabase(path: string, init: RequestInit = {}, token?: string): Promise<Response> {
  const config = configuration();
  if (config.mode !== 'live') throw new ApiError('Configure SUPABASE_URL and SUPABASE_ANON_KEY on the admin server.', 503);
  return fetch(`${config.url!.replace(/\/$/, '')}${path}`, { ...init, cache: 'no-store', headers: { apikey: config.key!, 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...init.headers }, signal: AbortSignal.timeout(30000) });
}
export function isAdmin(user: AuthUser) { return user.app_metadata?.role === 'super_admin' || user.app_metadata?.super_admin === true; }
export function setTokens(response: NextResponse, tokens: Tokens) {
  const options = { httpOnly: true, secure: process.env.NODE_ENV === 'production', sameSite: 'strict' as const, path: '/' };
  response.cookies.set('shopos_admin_access', tokens.access_token, { ...options, maxAge: tokens.expires_in });
  response.cookies.set('shopos_admin_refresh', tokens.refresh_token, { ...options, maxAge: 60 * 60 * 24 * 7 });
}
export function clearTokens(response: NextResponse) { response.cookies.delete('shopos_admin_access'); response.cookies.delete('shopos_admin_refresh'); }
export async function session(): Promise<{ user: AuthUser; token: string; refreshed?: Tokens }> {
  const cookieStore = cookies();
  let token = cookieStore.get('shopos_admin_access')?.value;
  let user: AuthUser | undefined, refreshed: Tokens | undefined;
  if (token) {
    const response = await supabase('/auth/v1/user', {}, token);
    if (response.ok) user = await response.json();
    else if (response.status >= 500) throw new ApiError('Authentication service is unavailable. Try again.', 503);
  }
  if (!user) {
    const refreshToken = cookieStore.get('shopos_admin_refresh')?.value;
    if (!refreshToken) throw new ApiError('Sign in to continue.', 401);
    const response = await supabase('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: JSON.stringify({ refresh_token: refreshToken }) });
    if (!response.ok) throw new ApiError('Session expired. Sign in again.', 401);
    refreshed = await response.json() as Tokens; token = refreshed.access_token; user = refreshed.user;
  }
  if (!user || !token || !isAdmin(user)) throw new ApiError('A super-admin account is required.', 403);
  return { user, token, refreshed };
}
export function errorResponse(error: unknown) {
  const response = NextResponse.json({ error: error instanceof ApiError ? error.message : 'The request failed. Check connectivity and server logs.' }, { status: error instanceof ApiError ? error.status : 502 });
  response.headers.set('Cache-Control', 'no-store');
  if (error instanceof ApiError && [401, 403].includes(error.status)) clearTokens(response);
  return response;
}
