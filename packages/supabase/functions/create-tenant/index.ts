import { authenticated, selectTenant, userClient } from "../_shared/auth.ts";
import { failure, HttpError, json, preflight } from "../_shared/http.ts";

Deno.serve(async (req) => {
  const early = preflight(req); if (early) return early;
  try {
    const { admin, user } = await authenticated(req);
    const body = await req.json();
    if (typeof body.name !== "string" || typeof body.shop_type !== "string" || typeof body.template_key !== "string") throw new HttpError(400, "Shop name, type and template are required");
    const { data, error } = await userClient(req).rpc("create_shop", {
      p_name: body.name, p_shop_type: body.shop_type, p_template_key: body.template_key,
      p_phone: body.phone ?? user.phone ?? null, p_address: body.address ?? {}, p_gstin: body.gstin ?? null,
    });
    if (error) throw new HttpError(400, error.message);
    await selectTenant(admin, user.id, data.tenant.id, "owner");
    return json({ ...data, refresh_session: true });
  } catch (error) { return failure(error); }
});
