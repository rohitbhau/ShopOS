# ShopOS small-business SaaS roadmap

This roadmap is based on the current repository audit on 1 October 2026. The React shop workspace and Flutter app provide a billing/inventory foundation. Live OTP, cloud migrations, provider billing and multi-device recovery still need integration verification before a paid launch.

## What is already present

- Shop onboarding, products, customers, POS, GST/discount calculation, saved invoice snapshots, customer credit and repayments.
- Local persistence and ordered outbox sync, with atomic and idempotent server batches.
- Tenant membership checks and owner/manager/cashier/viewer roles.
- Subscription creation, signed provider webhooks, payment/event deduplication and protected plan entitlements in the backend.
- React overview, inventory, customers, invoices, reports, generic shop modules and settings; the original platform console remains at `/admin`.

These are implemented capabilities, not proof that live deployment and payment flows have been verified.

## First release: one retail or kirana shop

Complete one dependable workflow before expanding into pharmacy, salon, restaurant or repair businesses. Template entities alone do not implement the transactions these businesses need.

| Priority | Gap in current implementation | Required result |
| --- | --- | --- |
| P0 | Mobile and server trial limits differ. A locally accepted trial sale may exceed the server free-plan limit and block the outbox. | One entitlement contract for plans, trial period, product/invoice/staff limits and overdue subscriptions, enforced consistently in server and clients. |
| P0 | React owners cannot buy/manage subscriptions; the mobile screen only opens checkout. Failed checkout reservations lack recovery, and renewal/grace expiry needs a reliable scheduled process. | Owner billing screens with configured prices/features, current status, next payment, payment history, retry, cancellation and clear trial/grace/read-only states. Provider-confirmed entitlement updates. |
| P0 | Platform console calls an `admin-api` Edge Function that is absent from the repository. | Implement and test authorized support operations with audit history before exposing live trial, plan, cancellation or refund actions. |
| P0 | Atomic record batches do not enforce a complete sale or repayment transaction. Client mutations can independently change financial records. | Dedicated server sale, repayment and adjustment transactions that validate prices, invoice totals, stock, customer balance and ledger together. |
| P0 | Permanent stock conflicts block later queued work; ordinary product edits can overwrite concurrent stock changes. | Separate stock adjustment events from product metadata edits, add version checks and actionable conflict review. Preserve rejected transactions until reviewed, and distinguish retryable failures. |
| P0 | Role visibility differs between mobile and React; all active tenant members can read broad financial records. | Define a clear role matrix and enforce allowed data in backend responses as well as both interfaces. Test cross-tenant and role boundaries. |
| P1 | Purchase and supplier modules only store records. | Purchase receipt increases stock, creates supplier payable and records subsequent supplier payment in one consistent flow. |
| P1 | Returns, refunds, expenses and day closing are not connected business flows. | Reverse stock/tax/ledger correctly on returns; record expense categories; reconcile opening cash, sales, repayments, refunds and closing cash. Keep gross profit separate from net profit. |
| P1 | Repayments reduce customer total but are not allocated to invoices. Credit invoice status does not reflect settlement. | Partial and split payments, invoice allocation, due dates, ageing, payment receipts and consent-based reminder delivery/status. |
| P1 | Web lacks owner staff/billing/import flows available or partially available on mobile. Staff creation requires a registered user UUID. | Phone-based staff invitation, permissions, deactivation, subscription screens, CSV import and practical barcode support across interfaces. |
| P1 | React rewrites one localStorage object for the entire business; corrupted state recovery is limited. | IndexedDB storage/outbox, safe corruption recovery, local export, tested tenant-scoped cloud backup/restore and retention. |
| P2 | Locale is stored but screens remain English; specialist modules use generic fields. | Marathi/Hindi strings, readable local-language receipts, short onboarding, and complete vertical-specific workflows after retail validation. |

The mobile checkout now sends the backend's `pro` plan identifier and limits checkout to owners. This fixes that particular mismatch; the rest of the billing lifecycle remains outstanding.

## Release acceptance checks

1. New owner signs in, creates a shop and completes a first sale from both mobile and web.
2. Cash and confirmed digital payment persist exactly once; credit sale and partial repayment reconcile invoice, customer balance and ledger after restart.
3. Two devices sell offline, reconnect in different orders, and resolve insufficient stock without losing invoices or permanently freezing later changes.
4. Trial end and every configured plan limit produce the same result locally and on the server.
5. Provider sandbox checkout succeeds and fails safely; duplicate/out-of-order webhooks, renewal failure, grace expiry, cancellation and interrupted checkout are covered.
6. Cashier/viewer cannot access forbidden financial data or perform owner actions; another tenant cannot read or mutate this tenant's records.
7. Purchase, return, expense and cash closing reconcile stock, receivables/payables and reports.
8. Backup recovery works after device loss or corrupt local state, without mixing tenants or replaying already accepted payments.

Run a small pilot before a public paid release. Track activation (first sale), recurring use, payment failures, sync errors, stock discrepancies, support requests and subscription renewal. Use those results to decide which specialist workflows to build next.

## Primary code areas

- `apps/admin/components/shop/ShopWorkspace.tsx` and `apps/admin/src/shop-store.ts`: React workspace, local business flows and sync.
- `apps/mobile/lib/data/local/shop_store.dart`, `data/sync/sync_engine.dart` and `features/management_screens.dart`: mobile flows, retry and management screens.
- `packages/supabase/migrations/010_secure_tenant_flows.sql`, `012_atomic_record_sync.sql` and `013_delivery_and_billing.sql`: membership, sync validation and billing lifecycle.
- `packages/supabase/functions/create-subscription`, `razorpay-webhook` and `trial-reminder`: provider checkout, events and expiry processing.
