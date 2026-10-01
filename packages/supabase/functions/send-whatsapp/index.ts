import { tenantContext } from "../_shared/auth.ts";
import { failure, HttpError, json, preflight } from "../_shared/http.ts";
import { deliverWhatsApp } from "../_shared/whatsapp.ts";

Deno.serve(async (req) => {
  const early = preflight(req); if (early) return early;
  try {
    const { tenantId } = await tenantContext(req, ["owner", "manager", "cashier"]);
    const body = await req.json(), recipient = body.recipient ?? body.to;
    if (!recipient || !body.template) throw new HttpError(400, "Recipient and template are required");
    if (body.document_url && !new URL(body.document_url).pathname.includes(`/${tenantId}/`)) throw new HttpError(403, "Document must belong to this shop");
    return json(await deliverWhatsApp({ tenantId, recipient, template: body.template, variables: body.variables,
      documentUrl: body.document_url, dedupKey: body.request_id ? `request:${String(body.request_id).slice(0,100)}` : undefined }));
  } catch (error) { return failure(error); }
});
