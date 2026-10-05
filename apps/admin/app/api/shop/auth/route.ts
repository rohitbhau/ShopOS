import { NextRequest } from 'next/server';
import { ApiError, configuration, requireOrigin, supabase } from '../../../../src/server';
import { checked, clearShopTokens, setShopTokens, shopError, shopResponse, shopSession, type ShopTokens } from '../../../../src/shop-server';

export const dynamic = 'force-dynamic';
export async function GET() {
  try {
    if (configuration().mode !== 'live') return shopResponse({ mode: configuration().mode });
    const auth = await shopSession(); return shopResponse({ user: auth.user }, auth);
  } catch (error) { return shopError(error); }
}
export async function POST(request: NextRequest) {
  try {
    requireOrigin(request);
    const body = await request.json();
    let phone = String(body.phone || '').replace(/[\s-]/g, '');
    if (/^[6-9]\d{9}$/.test(phone)) phone = `+91${phone}`;
    if (!/^\+91[6-9]\d{9}$/.test(phone)) throw new ApiError('Enter a valid Indian mobile number.');
    if (body.action === 'send_otp') {
      await checked(await supabase('/auth/v1/otp', { method: 'POST', body: JSON.stringify({ phone, create_user: true }) }));
      return shopResponse({ message: 'Verification code sent to your phone.' });
    }
    if (body.action !== 'verify_otp' || !/^\d{6}$/.test(String(body.token))) throw new ApiError('Enter the six-digit verification code.');
    const tokens = await checked(await supabase('/auth/v1/verify', { method: 'POST', body: JSON.stringify({ phone, token: body.token, type: 'sms' }) })) as ShopTokens;
    const response = shopResponse({ user: tokens.user }); setShopTokens(response, tokens); return response;
  } catch (error) { return shopError(error); }
}
export async function DELETE(request: NextRequest) {
  try {
    requireOrigin(request);
    try { const auth = await shopSession(); await checked(await supabase('/auth/v1/logout', { method: 'POST' }, auth.token)); }
    catch (error) { if (!(error instanceof ApiError && error.status === 401)) throw error; }
    const response = shopResponse({ ok: true }); clearShopTokens(response); return response;
  } catch (error) { return shopError(error); }
}
