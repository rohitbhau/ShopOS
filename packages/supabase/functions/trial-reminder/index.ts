import { serviceClient } from "../_shared/auth.ts";
import { failure, json, preflight, requireCron } from "../_shared/http.ts";
import { deliverWhatsApp } from "../_shared/whatsapp.ts";

Deno.serve(async (req) => {
  const early = preflight(req); if (early) return early;
  try {
    requireCron(req);
    const admin = serviceClient();
    const { data: expired, error: expiryError } = await admin.rpc("expire_subscription_access");
    if (expiryError) throw expiryError;
    const body = await req.json().catch(() => ({})), offset = Math.max(0, Number(body.offset) || 0);
    const { data: tenants, error } = await admin.from("tenants").select("id,name,phone,trial_ends_at").eq("is_active", true)
      .eq("plan", "free").not("phone", "is", null).gte("trial_ends_at", new Date(Date.now() - 86400000).toISOString()).order("id").range(offset, offset + 99);
    if (error) throw error;
    let sent = 0; const failures: string[] = [];
    for (const tenant of tenants ?? []) {
      const days = Math.max(0, Math.ceil((new Date(tenant.trial_ends_at).getTime() - Date.now()) / 86400000));
      if (![0, 1, 4].includes(days)) continue;
      try {
        const result = await deliverWhatsApp({ tenantId: tenant.id, recipient: tenant.phone, template: "trial_ending", system: true,
          dedupKey: `trial:${tenant.trial_ends_at}:${days}`, variables: { shop_name: tenant.name, days_left: String(days) } });
        if (!result.duplicate) sent++;
      } catch { failures.push(tenant.id); }
    }
    return json({ sent, failures, expired, next_offset: tenants?.length === 100 ? offset + 100 : null });
  } catch (error) { return failure(error); }
});
