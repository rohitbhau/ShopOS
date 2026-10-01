import { HttpError } from "./http.ts";

export function planId(plan: string, cycle: string): string {
  if (!["basic", "standard", "pro"].includes(plan) || !["monthly", "yearly"].includes(cycle)) throw new HttpError(400, "Choose a valid paid plan and billing cycle");
  const id = Deno.env.get(`RAZORPAY_PLAN_${plan.toUpperCase()}_${cycle.toUpperCase()}`);
  if (!id) throw new HttpError(503, "This billing plan has not been configured");
  return id;
}
export async function razorpay(path: string, body: Record<string, unknown>, method = "POST") {
  const key = Deno.env.get("RAZORPAY_KEY_ID"), secret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!key || !secret) throw new HttpError(503, "Billing is not configured");
  const response = await fetch(`https://api.razorpay.com/v1/${path}`, {
    method, headers: { Authorization: `Basic ${btoa(`${key}:${secret}`)}`, "Content-Type": "application/json" },
    body: JSON.stringify(body), signal: AbortSignal.timeout(15000), redirect: "error",
  });
  const result = await response.json();
  if (!response.ok) throw new HttpError(502, result.error?.description ?? "Payment provider rejected the request");
  return result;
}
