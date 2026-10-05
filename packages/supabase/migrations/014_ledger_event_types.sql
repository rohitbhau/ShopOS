-- Both clients post descriptive ledger event types. Preserve old credit/payment
-- records and custom field options while allowing the current immutable events.
CREATE OR REPLACE FUNCTION normalize_ledger_schema(p_schema JSONB)
RETURNS JSONB LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT jsonb_set(p_schema, '{fields}', COALESCE((
    SELECT jsonb_agg(CASE WHEN field->>'name' = 'type' THEN
      jsonb_set(field, '{options}', (
        SELECT jsonb_agg(option ORDER BY option::text)
        FROM (SELECT DISTINCT value AS option FROM jsonb_array_elements(
          COALESCE(field->'options', '[]'::jsonb) || '["credit","payment","credit_sale","payment_received"]'::jsonb
        )) allowed
      )) ELSE field END ORDER BY position)
    FROM jsonb_array_elements(COALESCE(p_schema->'fields', '[]'::jsonb)) WITH ORDINALITY AS fields(field, position)
  ), '[]'::jsonb));
$$;

UPDATE entities SET schema = normalize_ledger_schema(schema) WHERE name = 'ledger';
UPDATE shop_templates SET entities = (
  SELECT jsonb_agg(CASE WHEN entity->>'name' = 'ledger' THEN
    jsonb_set(entity, '{schema}', normalize_ledger_schema(entity->'schema'))
    ELSE entity END ORDER BY position)
  FROM jsonb_array_elements(entities) WITH ORDINALITY AS items(entity, position)
);
DROP FUNCTION normalize_ledger_schema(JSONB);
