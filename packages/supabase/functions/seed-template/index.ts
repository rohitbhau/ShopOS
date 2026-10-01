// Seed template - populate entities from template JSON
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Import templates
const TEMPLATES: Record<string, any> = {
  "retail_basic": {
    "entities": [
      {
        "name": "product",
        "label": "Product",
        "icon": "package",
        "is_system": true,
        "schema": {
          "fields": [
            {"name": "name", "type": "text", "label": "Product Name", "required": true},
            {"name": "sku", "type": "text", "label": "SKU/Barcode", "unique": true},
            {"name": "price", "type": "number", "label": "Price", "required": true},
            {"name": "cost", "type": "number", "label": "Cost Price"},
            {"name": "stock", "type": "number", "label": "Stock", "default": 0},
            {"name": "min_stock", "type": "number", "label": "Min Stock", "default": 5},
            {"name": "gst_rate", "type": "select", "label": "GST", "options": ["0", "5", "12", "18", "28"], "default": "18"}
          ]
        }
      },
      {
        "name": "customer",
        "label": "Customer",
        "icon": "user",
        "is_system": true,
        "schema": {
          "fields": [
            {"name": "name", "type": "text", "label": "Name", "required": true},
            {"name": "phone", "type": "text", "label": "Phone"},
            {"name": "email", "type": "text", "label": "Email"},
            {"name": "outstanding", "type": "number", "label": "Outstanding", "default": 0, "readonly": true}
          ]
        }
      },
      {
        "name": "invoice",
        "label": "Invoice",
        "icon": "file-text",
        "is_system": true,
        "schema": {
          "fields": [
            {"name": "invoice_number", "type": "text", "label": "Invoice #", "required": true, "readonly": true},
            {"name": "invoice_date", "type": "datetime", "label": "Date", "required": true},
            {"name": "customer_id", "type": "text", "label": "Customer"},
            {"name": "items", "type": "json", "label": "Items", "required": true},
            {"name": "total", "type": "number", "label": "Total", "readonly": true, "required": true},
            {"name": "payment_mode", "type": "select", "label": "Payment", "options": ["cash", "upi", "card", "credit"], "default": "cash"}
          ]
        }
      }
    ]
  }
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const authHeader = req.headers.get("Authorization")!;
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { app_id, template_key } = await req.json();

    if (!app_id || !template_key) {
      return new Response(JSON.stringify({ error: "Missing app_id or template_key" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const template = TEMPLATES[template_key];
    if (!template) {
      return new Response(JSON.stringify({ error: "Template not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Insert entities
    const insertedEntities = [];
    for (const entity of template.entities) {
      const { data, error } = await supabaseClient
        .from("entities")
        .insert({
          app_id,
          name: entity.name,
          label: entity.label,
          icon: entity.icon,
          schema: entity.schema,
          is_system: entity.is_system,
        })
        .select()
        .single();

      if (error) {
        console.error("Error inserting entity:", error);
        continue;
      }

      insertedEntities.push(data);
    }

    return new Response(
      JSON.stringify({
        success: true,
        entities: insertedEntities,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
