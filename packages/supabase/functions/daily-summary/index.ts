import { serviceClient } from "../_shared/auth.ts";
import { failure, json, preflight, requireCron } from "../_shared/http.ts";
import { deliverWhatsApp } from "../_shared/whatsapp.ts";

Deno.serve(async (req) => {
  const early = preflight(req); if (early) return early;
  try {
    requireCron(req);
    const admin = serviceClient(), date = new Date(Date.now() + 19800000).toISOString().slice(0, 10);
    const body = await req.json().catch(() => ({})), offset = Math.max(0, Number(body.offset) || 0);
    const { data: tenants, error } = await admin.from("tenants").select("id,name,phone").eq("is_active", true)
      .in("plan", ["standard", "pro"]).not("phone", "is", null).order("id").range(offset, offset + 99);
    if (error) throw error;
    let sent = 0; const failures: string[] = [];
    for (const tenant of tenants ?? []) {
      try {
        const { data: sales, error: salesError } = await admin.rpc("shop_daily_sales", { p_tenant: tenant.id, p_date: date });
        if (salesError) throw salesError;
        const result = await deliverWhatsApp({ tenantId: tenant.id, recipient: tenant.phone, template: "daily_summary", dedupKey: `daily:${date}`,
          variables: { shop_name: tenant.name, date, total: String(sales.total), invoices: String(sales.invoices) } });
        if (!result.duplicate) sent++;
      } catch { failures.push(tenant.id); }
    }
    return json({ sent, failures, next_offset: tenants?.length === 100 ? offset + 100 : null });
  } catch (error) { return failure(error); }
});
