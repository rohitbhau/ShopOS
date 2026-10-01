import { NextRequest, NextResponse } from 'next/server';
import { ApiError, errorResponse, requireOrigin, session, setTokens, supabase } from '../../../src/server';

export const dynamic = 'force-dynamic';
const actions = new Set(['snapshot', 'tenant_detail', 'publish_entity', 'save_workflow', 'update_flag', 'extend_trial', 'subscription_action', 'readonly_view', 'templates']);
export async function POST(request: NextRequest) {
  try {
    requireOrigin(request);
    const auth = await session();
    const raw = await request.text();
    if (raw.length > 256000) throw new ApiError('Request is too large.', 413);
    const body = JSON.parse(raw);
    if (!actions.has(body.action)) throw new ApiError('Unknown admin action.');
    const remote = await supabase('/functions/v1/admin-api', { method: 'POST', body: JSON.stringify(body) }, auth.token);
    let data: unknown;
    try { data = await remote.json(); } catch { throw new ApiError('Admin service returned an invalid response. Check deployment.', 502); }
    const response = NextResponse.json(data, { status: remote.status });
    response.headers.set('Cache-Control', 'no-store');
    if (auth.refreshed) setTokens(response, auth.refreshed);
    return response;
  } catch (error) { return errorResponse(error); }
}
