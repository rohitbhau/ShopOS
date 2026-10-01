export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-hub-signature-256",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});

export function bearer(req: Request): string | null {
  const value = req.headers.get("Authorization");
  return value?.startsWith("Bearer ") ? value.slice(7) : null;
}

export async function hmacSha256(secret: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let result = 0;
  for (let index = 0; index < left.length; index++) result |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return result === 0;
}

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

export function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  return null;
}

export function failure(error: unknown): Response {
  if (error instanceof HttpError) return json({ error: error.message }, error.status);
  if (error instanceof SyntaxError) return json({ error: "Invalid JSON" }, 400);
  console.error("Request failed", error instanceof Error ? error.message : "Unknown error");
  return json({ error: "The operation could not be completed" }, 500);
}

export function requireCron(req: Request): void {
  const configured = Deno.env.get("CRON_SECRET");
  const supplied = bearer(req);
  if (!configured || !supplied || !constantTimeEqual(configured, supplied)) throw new HttpError(401, "Unauthorized scheduled request");
}
