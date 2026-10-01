import { serviceClient } from "../_shared/auth.ts";
import { constantTimeEqual, failure, hmacSha256, HttpError, json, preflight } from "../_shared/http.ts";

Deno.serve(async (req) => {
  const early = preflight(req); if (early) return early;
  try {
    const raw = await req.text(), signature = req.headers.get("x-razorpay-signature"), secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
    if (!signature || !secret || !constantTimeEqual(signature, await hmacSha256(secret, raw))) throw new HttpError(401, "Invalid signature");
    const event = JSON.parse(raw);
    if (!String(event.event).startsWith("subscription.") || !event.payload?.subscription?.entity?.id) return json({ ignored: true });
    const eventId = req.headers.get("x-razorpay-event-id") ?? await hmacSha256(secret, raw);
    const { data, error } = await serviceClient().rpc("apply_razorpay_event", { p_event_id: eventId, p_event: event });
    if (error) throw new HttpError(503, "Webhook processing failed; retry delivery");
    return json(data);
  } catch (error) { return failure(error); }
});
