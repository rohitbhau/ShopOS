import { NextRequest, NextResponse } from 'next/server';
import { ApiError, clearTokens, errorResponse, isAdmin, requireOrigin, session, setTokens, supabase } from '../../../src/server';

export const dynamic = 'force-dynamic';
export async function GET() {
  try {
    const auth = await session();
    const response = NextResponse.json({ email: auth.user.email });
    response.headers.set('Cache-Control', 'no-store');
    if (auth.refreshed) setTokens(response, auth.refreshed);
    return response;
  } catch (error) { return errorResponse(error); }
}
export async function POST(request: NextRequest) {
  try {
    requireOrigin(request);
    const input = await request.json();
    if (typeof input.email !== 'string' || input.email.length > 254 || typeof input.password !== 'string' || input.password.length > 512) throw new ApiError('Enter a valid email and password.');
    const auth = await supabase('/auth/v1/token?grant_type=password', { method: 'POST', body: JSON.stringify({ email: input.email, password: input.password }) });
    if (!auth.ok) throw new ApiError(auth.status === 429 ? 'Too many attempts. Please wait before signing in again.' : 'Sign-in failed. Check your email and password.', auth.status === 429 ? 429 : 401);
    const tokens = await auth.json();
    if (!isAdmin(tokens.user)) {
      await supabase('/auth/v1/logout', { method: 'POST' }, tokens.access_token);
      throw new ApiError('A super-admin account is required.', 403);
    }
    const response = NextResponse.json({ email: tokens.user.email });
    setTokens(response, tokens); return response;
  } catch (error) { return errorResponse(error); }
}
export async function DELETE(request: NextRequest) {
  try {
    requireOrigin(request);
    try { const auth = await session(); await supabase('/auth/v1/logout', { method: 'POST' }, auth.token); } catch { /* Always clear the local session, including expired sessions. */ }
    const response = NextResponse.json({ success: true }); clearTokens(response); return response;
  } catch (error) { return errorResponse(error); }
}
