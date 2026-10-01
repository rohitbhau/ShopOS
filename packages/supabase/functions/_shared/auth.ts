import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";
import { bearer, HttpError } from "./http.ts";

export function serviceClient() {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } });
}
export function userClient(req: Request) {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } }, auth: { persistSession: false } });
}
export async function authenticated(req: Request) {
  const token = bearer(req);
  if (!token) throw new HttpError(401, "Sign in to continue");
  const admin = serviceClient();
  const { data: { user }, error } = await admin.auth.getUser(token);
  if (error || !user) throw new HttpError(401, "Your session has expired");
  return { admin, user };
}
export async function tenantContext(req: Request, roles = ["owner", "manager", "cashier", "viewer"]) {
  const { admin, user } = await authenticated(req);
  const tenantId = user.app_metadata?.tenant_id;
  if (!tenantId) throw new HttpError(403, "Select a shop first");
  const { data: member, error } = await admin.from("memberships").select("role,tenant_id,tenants!inner(is_active)")
    .eq("user_id", user.id).eq("tenant_id", tenantId).eq("is_active", true).eq("tenants.is_active", true).maybeSingle();
  if (error || !member || !roles.includes(member.role)) throw new HttpError(403, "You do not have permission for this action");
  return { admin, user, tenantId: String(tenantId), role: String(member.role) };
}
export async function selectTenant(admin: ReturnType<typeof serviceClient>, userId: string, tenantId: string, role: string) {
  const { error } = await admin.auth.admin.updateUserById(userId, { app_metadata: { tenant_id: tenantId, shop_role: role } });
  if (error) throw new HttpError(500, "Shop created, but session selection failed. Select the shop again.");
}
