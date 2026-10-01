import { serviceClient } from "../_shared/auth.ts";
import { constantTimeEqual, failure, hmacSha256, HttpError, json, preflight } from "../_shared/http.ts";

Deno.serve(async (req) => {
  try {
    if (req.method === "GET") {
      const url = new URL(req.url), expected = Deno.env.get("WHATSAPP_VERIFY_TOKEN"), actual = url.searchParams.get("hub.verify_token");
      if (!expected || !actual || url.searchParams.get("hub.mode") !== "subscribe" || !constantTimeEqual(actual, expected)) throw new HttpError(403, "Invalid verification token");
      return new Response(url.searchParams.get("hub.challenge") ?? "");
    }
    const early = preflight(req); if (early) return early;
    const raw = await req.text(), signature = req.headers.get("x-hub-signature-256")?.replace(/^sha256=/, ""), secret = Deno.env.get("WHATSAPP_APP_SECRET");
    if (!signature || !secret || !constantTimeEqual(signature, await hmacSha256(secret, raw))) throw new HttpError(401, "Invalid signature");
    const payload = JSON.parse(raw), admin = serviceClient();
    for (const entry of payload.entry ?? []) for (const change of entry.changes ?? []) for (const status of change.value?.statuses ?? []) {
      if (!["sent", "delivered", "read", "failed"].includes(status.status)) continue;
      const { data: log } = await admin.from("whatsapp_logs").select("id,status").eq("provider_message_id", status.id).maybeSingle();
      if (!log) continue;
      const rank: Record<string, number> = { queued: 0, sent: 1, delivered: 2, read: 3, failed: 4 };
      if (rank[status.status] <= rank[log.status]) continue;
      const { error } = await admin.from("whatsapp_logs").update({ status: status.status,
        ...(status.errors ? { error: JSON.stringify(status.errors).slice(0,2000) } : {}) }).eq("id", log.id);
      if (error) throw error;
    }
    return json({ received: true });
  } catch (error) { return failure(error); }
});
