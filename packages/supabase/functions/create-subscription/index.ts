import { tenantContext } from "../_shared/auth.ts";
import { failure, HttpError, json, preflight } from "../_shared/http.ts";
import { planId, razorpay } from "../_shared/razorpay.ts";

Deno.serve(async (req) => {
  const early = preflight(req); if (early) return early;
  try {
    const { admin, user, tenantId } = await tenantContext(req, ["owner"]);
    const body = await req.json();
    if (body.action === "cancel") {
      const { data: current } = await admin.from("subscriptions").select("id,razorpay_sub_id").eq("tenant_id", tenantId)
        .in("status", ["active", "halted", "past_due"]).not("razorpay_sub_id", "is", null).order("created_at", { ascending: false }).limit(1).maybeSingle();
      if (!current) throw new HttpError(404, "No paid subscription to cancel");
      const provider = await razorpay(`subscriptions/${current.razorpay_sub_id}/cancel`, { cancel_at_cycle_end: 1 });
      const { error } = await admin.from("subscriptions").update({ cancel_at_period_end: true }).eq("id", current.id);
      if (error) throw error;
      return json({ success: true, cancel_at_period_end: true, provider_status: provider.status });
    }
    const plan = String(body.plan ?? ""), cycle = String(body.billing_cycle ?? "monthly");
    const providerPlan = planId(plan, cycle);
    const { data: active } = await admin.from("subscriptions").select("id").eq("tenant_id", tenantId).eq("status", "active").not("razorpay_sub_id", "is", null).limit(1).maybeSingle();
    if (active) throw new HttpError(409, "Cancel the current subscription before starting a new one; support can schedule a plan change");
    const { data: existing } = await admin.from("subscriptions").select("*").eq("tenant_id", tenantId).eq("status", "pending").maybeSingle();
    if (existing) {
      if (existing.plan !== plan || existing.billing_cycle !== cycle) throw new HttpError(409, "A different checkout is pending; complete it or contact support");
      if (!existing.checkout_url) throw new HttpError(409, "Checkout creation is processing; try again shortly or contact support");
      return json({ checkout_url: existing.checkout_url, subscription_id: existing.razorpay_sub_id, key_id: Deno.env.get("RAZORPAY_KEY_ID") });
    }
    const { data: reservation, error: insertError } = await admin.from("subscriptions").insert({ tenant_id: tenantId, plan, billing_cycle: cycle, status: "pending" }).select("id").single();
    if (insertError) throw new HttpError(409, "A checkout is already being created. Try again shortly.");
    // Reservation remains pending on an ambiguous network failure, avoiding duplicate mandates.
    const provider = await razorpay("subscriptions", { plan_id: providerPlan, total_count: cycle === "yearly" ? 10 : 120,
      quantity: 1, customer_notify: 1, notes: { tenant_id: tenantId, subscription_id: reservation.id, plan, billing_cycle: cycle },
      ...(user.phone ? { notify_info: { notify_phone: user.phone } } : {}),
    });
    const { error } = await admin.from("subscriptions").update({ razorpay_sub_id: provider.id, checkout_url: provider.short_url }).eq("id", reservation.id);
    if (error) throw error;
    return json({ checkout_url: provider.short_url, subscription_id: provider.id, key_id: Deno.env.get("RAZORPAY_KEY_ID") });
  } catch (error) { return failure(error); }
});
