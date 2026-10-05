# Web workspace

The React shop interface is `/` in `apps/admin`; the platform administration console is `/admin`. Both run on the same Next.js server and use separate sessions.

## Configuration

```dotenv
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=YOUR_PUBLIC_OR_ANON_KEY
# For deployments behind a proxy:
ADMIN_ORIGIN=https://shop.example.com
```

Put these values in `apps/admin/.env.local` or server environment variables. Never use a service-role key here. Missing both values enables the local demo. Setting only one value displays a configuration error.

Apply backend migrations in order, including `014_ledger_event_types.sql`. This migration allows both the existing `credit`/`payment` ledger events and the current `credit_sale`/`payment_received` names, preserving historical data and custom options.

Deploy `create-tenant` and `auth-set-tenant-claim`; configure the Supabase phone/SMS provider. The owner interface sends and verifies six-digit OTPs. `create-tenant` creates the selected template and provisions owner membership. Claims are refreshed before loading the tenant. All database reads and writes use the authenticated user's token and backend RLS policies.

## Sessions and persistence

- Shop authentication: `/api/shop/auth`; HTTP-only `shopos_shop_access` and `shopos_shop_refresh` cookies.
- Administration authentication: `/api/auth`; separate HTTP-only administration cookies and trusted super-admin metadata.
- Shop snapshot/onboarding: `/api/shop`; template schemas, records, and shop metadata.
- Shop outbox submission: `/api/shop/sync`; session tenant checks, owner-only profile updates, and atomic `sync_mutations` RPC batches.

Mutations update a copied state, validate stock/balances/permissions, and persist the full transaction before reporting success. Storage quota errors and conflicting tab revisions prevent the save. Live batches retain their mutation IDs for idempotent retries. A failed head batch blocks later work. Remote snapshots only replace local records after the outbox drains.

Browser demo data uses a separate localStorage key. Signed-in data is keyed by user and tenant. Sign-out preserves the shop's records and queue, and removes the saved-workspace pointer. Backups for live shops are exports; local demo backups may be restored after validation.

## Offline and payments

The production service worker caches the public shop shell and hashed assets after the first successful visit. It never caches authentication or API responses. An already-signed-in shop can be reopened with **Open saved workspace offline** if its records were previously saved on that browser. Cloud authentication and sync need a connection. Development mode does not register the service worker.

UPI/card sales require manual receipt confirmation; opening a UPI link does not confirm payment. Credit sales require a selected customer. Repayments cannot exceed the outstanding balance. Invoices retain original product details after products change or are removed. A credit sale remains labeled as a credit sale; the customer ledger shows later repayments.

Browser invoices use Print / Save PDF, with A4 or 80 mm layouts. The web barcode field accepts keyboard/USB scanner input; camera scanning is in the mobile app.

## Validation and deployment

Run `npm ci`, `npm test`, `npm run typecheck`, `npm run build`, and `npm run test:e2e` in `apps/admin`. The Playwright configuration uses installed Windows Chrome; override it for Linux/macOS. The production server is `npm start` and requires Node.js.

Next.js was migrated using its [version 15 upgrade guide](https://nextjs.org/docs/app/guides/upgrading/version-15). Cookie reads now use the asynchronous API. The framework and PostCSS versions are pinned in the package/lock files.

Live SMS, backend migrations, and cross-device synchronization are deployment checks. Provider credentials, billing/webhook configuration, and staff provisioning remain server responsibilities. The local demo and automated tests do not prove those external services are configured.
