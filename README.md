# ShopOS

A shop workspace for billing, inventory, customers, credit balances, invoices, and sales reports. The project contains a React web application, a Flutter mobile application, and a Supabase backend.

## Run the React web application

Requires Node.js 20.9 or newer. From this directory:

```powershell
npm --prefix apps/admin ci
npm run dev
```

Open **http://localhost:3000** for the shop workspace. The administration console is at **http://localhost:3000/admin**.

Without Supabase environment variables, the shop opens a clearly labeled local demo. Sample sales drive the dashboard and reports. Products, customers, sales, repayments, and settings persist in this browser. Settings includes backup export, local backup restore, and an explicit demo reset.

The web interface includes:

- Dashboard with sales periods, recent invoices, bestsellers, and low stock alerts.
- Point of sale with search/barcode input, stock limits, customer selection, discounts, GST, cash, UPI, card, and credit.
- Product management with categories, inventory adjustments, list/grid views, and CSV export.
- Customer management, credit ledger, and validated repayment recording.
- Invoice search, payment filters, A4/80 mm printing, and browser Save as PDF.
- Reports and CSV export, template modules, shop settings, and backup tools.
- Desktop/tablet layouts, mobile navigation, keyboard-accessible dialogs, and an offline shell after the first successful production visit.

Web camera scanning is not implemented; use a USB barcode scanner or enter the barcode in the search box. Mobile includes camera scanning.

## Connect a real shop

Copy `apps/admin/.env.example` to `apps/admin/.env.local`, enter your Supabase URL and public/anon key, and restart the server. Do not put a service-role key in the web application.

Apply **all migrations through `014_ledger_event_types.sql`**, deploy `create-tenant` and `auth-set-tenant-claim`, and configure Supabase phone authentication with your SMS provider. The web owner flow uses mobile-number OTP, shop onboarding, role-based access, a durable local outbox, atomic sale batches, and automatic/manual sync.

The shop session and administration session use separate HTTP-only cookies. Administration requires a trusted super-admin account. Configure `ADMIN_ORIGIN` when serving behind a reverse proxy; it applies to both consoles.

Local demo data is separate from signed-in shop data. A live shop stores its cached records and queued changes under its user and tenant identity. Cloud sync never treats demo edits as live records. Saved changes remain queued if the network or backend fails.

See [web configuration and behavior](packages/docs/web.md) for details. Live OTP delivery, cross-device sync, provider billing, and database migrations require a configured backend and must be verified against that deployment.

## Run the Flutter app

```powershell
cd apps/mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

The app starts without cloud credentials and supports a persistent local demo. Choose **Create shop**, enter a shop name, and optionally include sample products and a customer.

For cloud sign-in:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY
```

The running mobile app uses `ShopStore` and `ShopSession`, rather than the older disconnected screens. Its data is saved in Drift/SQLite, with tenant-scoped queued changes. It includes billing, customer repayments, invoice PDFs, reports, template modules, settings/backup, CSV product import, and connected staff/subscription screens. Staff accounts must already be registered. Subscription checkout requires Razorpay configuration and its confirmation webhook.

## Build and verify

```powershell
# React web
npm run typecheck
npm test
npm run build
npm start

# Browser smoke tests (production build required)
npm run test:e2e

# Flutter
cd apps/mobile
flutter analyze
flutter test
flutter build apk --debug
```

The browser suite uses installed Chrome on Windows when available, otherwise Playwright Chromium (`npx playwright install chromium` from `apps/admin`). A custom browser path can be set with `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`. It covers the sale/repayment/reload path, stock/payment validation, mobile/tablet layouts, administration access, API access checks, and offline reopening. Screenshots are written to `apps/admin/test-results`.

The mobile suite covers forms, computed fields, onboarding, sale transactions, ordered retries, offline queue retention, database reopen, invoice PDFs, and phone/tablet screen rendering.

## Project layout

| Directory | Purpose |
| --- | --- |
| `apps/admin` | React/Next.js shop web app and separate administration console |
| `apps/mobile` | Flutter application with local Drift storage and cloud sync |
| `apps/landing` | Public marketing website |
| `packages/shared` | Shared administration schemas and expression evaluation |
| `packages/supabase` | SQL migrations, template catalog, and Edge Functions |

The dated status documents in the root describe earlier work. This README describes the current entry points; those older completion percentages are not verification results.

See [the small-business SaaS roadmap](packages/docs/saas-roadmap.md) for verified launch gaps, priorities and acceptance checks before taking monthly subscriptions.
