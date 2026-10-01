import { serviceClient } from "./auth.ts";
import { HttpError } from "./http.ts";
export { serviceClient } from "./auth.ts";

const templates = new Set(["invoice_ready", "order_confirmed", "low_stock_alert", "payment_reminder", "daily_summary", "trial_ending", "staff_invite"]);
export async function sendWhatsAppTemplate(input: { recipient: string; template: string; variables?: Record<string, string>; documentUrl?: string }) {
  if (!/^\+?[1-9]\d{7,14}$/.test(input.recipient)) throw new HttpError(400, "Use an international phone number");
  if (!templates.has(input.template)) throw new HttpError(400, "Unknown utility template");
  if (input.documentUrl) {
    const url = new URL(input.documentUrl);
    const project = new URL(Deno.env.get("SUPABASE_URL")!);
    if (url.protocol !== "https:" || url.origin !== project.origin || !url.pathname.startsWith("/storage/v1/object/")) throw new HttpError(400, "Invoice documents must use this shop's Supabase storage");
  }
  const token = Deno.env.get("WHATSAPP_ACCESS_TOKEN"), phone = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  if (!token || !phone) throw new HttpError(503, "WhatsApp is not configured");
  const values = Object.values(input.variables ?? {});
  if (values.length > 15 || values.some(v => typeof v !== "string" || v.length > 1024)) throw new HttpError(400, "Invalid template variables");
  const parameters = values.map(text => ({ type: "text", text }));
  const components: Record<string, unknown>[] = parameters.length ? [{ type: "body", parameters }] : [];
  if (input.documentUrl) components.unshift({ type: "header", parameters: [{ type: "document", document: { link: input.documentUrl, filename: "invoice.pdf" } }] });
  const version = Deno.env.get("WHATSAPP_GRAPH_VERSION") ?? "v23.0";
  const response = await fetch(`https://graph.facebook.com/${version}/${phone}/messages`, {
    method: "POST", headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ messaging_product: "whatsapp", to: input.recipient, type: "template",
      template: { name: input.template, language: { code: Deno.env.get("WHATSAPP_TEMPLATE_LANGUAGE") ?? "en" }, components } }),
    signal: AbortSignal.timeout(15000), redirect: "error",
  });
  const payload = await response.json();
  if (!response.ok) throw new HttpError(502, payload.error?.message ?? "WhatsApp delivery failed");
  return payload;
}

export async function deliverWhatsApp(input: { tenantId: string; recipient: string; template: string; variables?: Record<string, string>; documentUrl?: string; dedupKey?: string; system?: boolean }) {
  const admin = serviceClient();
  const { data: logId, error } = await admin.rpc("reserve_whatsapp", { p_tenant: input.tenantId, p_recipient: input.recipient,
    p_template: input.template, p_dedup: input.dedupKey ?? null, p_system: input.system ?? false });
  if (error) throw new HttpError(429, error.message);
  if (!logId) return { duplicate: true };
  try {
    const provider = await sendWhatsAppTemplate(input);
    const { error: logError } = await admin.from("whatsapp_logs").update({ status: "sent", provider_message_id: provider.messages?.[0]?.id,
      metadata: { variables: input.variables ?? {} } }).eq("id", logId);
    if (logError) throw logError;
    return { success: true, message_id: provider.messages?.[0]?.id };
  } catch (error) {
    await admin.from("whatsapp_logs").update({ status: "failed", error: error instanceof Error ? error.message : String(error) }).eq("id", logId);
    throw error;
  }
}
