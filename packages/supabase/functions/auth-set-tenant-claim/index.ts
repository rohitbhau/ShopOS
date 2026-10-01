import { authenticated, selectTenant } from "../_shared/auth.ts";
import { failure, HttpError, json, preflight } from "../_shared/http.ts";

Deno.serve(async (req) => {
  const early = preflight(req); if (early) return early;
  try {
    const { admin, user } = await authenticated(req);
    const body = await req.json().catch(() => ({}));
    let query = admin.from("memberships").select("tenant_id,role,tenants!inner(is_active)").eq("user_id", user.id)
      .eq("is_active", true).eq("tenants.is_active", true).order("created_at").limit(1);
    if (body.tenant_id) query = query.eq("tenant_id", body.tenant_id);
    const { data, error } = await query.maybeSingle();
    if (error) throw new HttpError(500, "Could not load your shops");
    if (!data) {
      if (body.tenant_id) throw new HttpError(403, "You are not an active member of this shop");
      const { error: clearError } = await admin.auth.admin.updateUserById(user.id, { app_metadata: { tenant_id: null, shop_role: null } });
      if (clearError) throw clearError;
      return json({ claims: { tenant_id: null, role: null }, refresh_session: true });
    }
    await selectTenant(admin, user.id, data.tenant_id, data.role);
    return json({ claims: { tenant_id: data.tenant_id, role: data.role }, refresh_session: true });
  } catch (error) { return failure(error); }
});
