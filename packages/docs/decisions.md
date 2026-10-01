# Architecture Decision Record (ADR)

This document tracks all significant architectural and technical decisions made during ShopOS development.

## ADR-001: Multi-Tenant Architecture with RLS

**Date**: 2024-09
**Status**: Accepted

**Context**: Need strict data isolation between tenants while keeping infrastructure costs low.

**Decision**: Use Supabase Row-Level Security (RLS) with tenant_id in JWT custom claims. All tables include tenant_id with RLS policies enforcing isolation.

**Consequences**:
- ✅ Strong security with database-enforced isolation
- ✅ Single database for all tenants reduces costs
- ✅ No application-level filtering required
- ⚠️ Must ensure JWT claims are always set correctly
- ⚠️ Cross-tenant queries require service role

**Alternatives Considered**:
- Database-per-tenant: Too expensive at scale
- Schema-per-tenant: Complex migrations
- Application-level filtering: Risk of bugs exposing data

---

## ADR-002: Offline-First with Drift + Outbox Pattern

**Date**: 2024-09
**Status**: Accepted

**Context**: Target users have unreliable internet. Billing must work offline.

**Decision**: Use Drift (SQLite) for local storage with SQLCipher encryption. All mutations write to local DB first, then queue in outbox table for background sync.

**Consequences**:
- ✅ App works with zero internet
- ✅ No data loss during offline periods
- ✅ Fast UI (no network latency)
- ⚠️ Sync conflicts possible (using last-write-wins)
- ⚠️ Increased complexity in data layer
- ⚠️ Must handle eventual consistency

**Implementation Details**:
- Outbox table: queued_actions with retry logic
- Sync engine runs every 30s + on connectivity change
- Conflict resolution: last-write-wins based on updated_at timestamp
- Invoice numbers: device-prefixed sequences for offline uniqueness

---

## ADR-003: Low-Code Engine with JSONB Storage

**Date**: 2024-09
**Status**: Accepted

**Context**: Different shop types need different data models. Users want to customize fields without code.

**Decision**: Store entity schemas as JSON in entities table. Store all records as JSONB in single records table. Dynamic forms render from schema at runtime.

**Consequences**:
- ✅ Infinite flexibility without migrations
- ✅ Users can add fields instantly
- ✅ Easy to add new shop templates
- ⚠️ No compile-time type safety
- ⚠️ JSONB queries slower than normalized tables
- ⚠️ Must validate data against schema in app

**Schema Format**:
```json
{
  "entity": "product",
  "label": "Product",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "price", "type": "number", "required": true}
  ]
}
```

**Performance**: GIN index on records.data for fast JSONB queries. Tested with 100K records per tenant.

---

## ADR-004: Flutter + Riverpod for Mobile

**Date**: 2024-09
**Status**: Accepted

**Context**: Need fast development, native performance, single codebase.

**Decision**: Flutter 3.x with Riverpod 2.x for state management.

**Consequences**:
- ✅ Single codebase for Android (iOS later)
- ✅ Fast hot reload during development
- ✅ Native performance
- ✅ Riverpod provides excellent DI and state management
- ⚠️ APK size ~40MB
- ⚠️ iOS requires separate testing/deployment

**Alternatives Considered**:
- React Native: Slower, bridge overhead
- Native Android: Can't afford two codebases
- PWA: Poor offline support, no barcode

---

## ADR-005: Supabase for Backend

**Date**: 2024-09
**Status**: Accepted

**Context**: Need managed Postgres, auth, real-time, edge functions, storage in one platform.

**Decision**: Supabase for entire backend (BaaS).

**Consequences**:
- ✅ Fast development (no DevOps)
- ✅ Built-in auth with RLS
- ✅ Real-time subscriptions
- ✅ Edge functions for server logic
- ✅ Cost-effective at small scale
- ⚠️ Vendor lock-in
- ⚠️ Limited control over infra
- ⚠️ Must use Postgres (no NoSQL)

**Cost Estimate**: 
- Free tier: First 2 projects
- Pro: $25/month + usage
- Expected at 100 tenants: ~$50-100/month

---

## ADR-006: Invoice Numbers - Device-Prefixed Sequences

**Date**: 2024-09
**Status**: Accepted

**Context**: Invoice numbers must be unique and sequential, but app works offline on multiple devices.

**Decision**: Use device-prefix + local sequence. Format: `{DEVICE_ID}-{SEQ}` e.g. `A1B2-0001`. On sync, store in server as-is.

**Consequences**:
- ✅ Works offline
- ✅ No collisions between devices
- ✅ Sequential per device
- ⚠️ Not sequential across devices
- ⚠️ Prefix visible to customer

**Alternatives Considered**:
- Server-assigned: Requires online
- UUID: Not human-friendly
- Tenant-wide sequence with offline buffer: Complex, gaps in sequence

**User Education**: Explain in docs that multi-device shops will see non-sequential numbers.

---

## ADR-007: WhatsApp Cloud API for Notifications

**Date**: 2024-09
**Status**: Accepted

**Context**: SMS is expensive (Rs.0.25-0.40/msg). Email not checked. WhatsApp has 100% penetration.

**Decision**: WhatsApp Cloud API (Meta) for all notifications.

**Consequences**:
- ✅ Rs.0.125/msg (half of SMS)
- ✅ 100% delivery rate
- ✅ Rich media (PDF invoices)
- ⚠️ Requires business verification
- ⚠️ Template approval process (48h)
- ⚠️ Rate limits (1000 msg/day initially)

**Templates to Register**:
- invoice_ready
- order_confirmed
- low_stock_alert
- payment_reminder
- daily_summary
- trial_ending
- staff_invite

---

## ADR-008: Razorpay for Subscription Billing

**Date**: 2024-09
**Status**: Accepted

**Context**: Need Indian payment gateway with subscription support.

**Decision**: Razorpay Subscriptions API.

**Consequences**:
- ✅ UPI, cards, netbanking, wallets
- ✅ Automatic retry on failure
- ✅ Subscription management built-in
- ✅ 2% + GST fee (industry standard)
- ⚠️ Must handle webhooks for status updates
- ⚠️ Test mode limited

**Webhook Events**:
- subscription.charged → update subscription status
- subscription.halted → grace period, then downgrade
- subscription.cancelled → immediate downgrade

---

## ADR-009: Thermal Printer Support via Bluetooth

**Date**: 2024-09
**Status**: Accepted

**Context**: Most small shops use 58mm/80mm thermal printers.

**Decision**: Support thermal printing via Bluetooth. Also generate PDF for A4 if needed.

**Consequences**:
- ✅ Fast printing (< 2 seconds)
- ✅ Low cost per print
- ✅ Portable (battery-powered printers)
- ⚠️ Must handle multiple printer models
- ⚠️ ESC/POS command variations

**Supported Formats**:
- 58mm thermal (2 inch)
- 80mm thermal (3 inch)
- A4 PDF (share via WhatsApp)

---

## ADR-010: Barcode Scanning with Mobile Camera

**Date**: 2024-09
**Status**: Accepted

**Context**: Manual SKU entry is slow and error-prone.

**Decision**: mobile_scanner package for in-app barcode scanning.

**Consequences**:
- ✅ Fast product lookup
- ✅ No external hardware needed
- ✅ Supports QR, EAN-13, Code-128
- ⚠️ Camera permission required
- ⚠️ Poor lighting affects accuracy

**UX**: Scan button in POS, long-press to type manually.

---

## ADR-011: SQLCipher for Local Database Encryption

**Date**: 2024-09
**Status**: Accepted

**Context**: Local database contains customer data, must be encrypted.

**Decision**: Use sqflite_sqlcipher instead of plain sqflite.

**Consequences**:
- ✅ AES-256 encryption at rest
- ✅ Compliant with data protection
- ✅ Minimal performance overhead
- ⚠️ Password must be securely stored
- ⚠️ No access if password lost

**Key Management**: Derived from device ID + user pin. Stored in flutter_secure_storage.

---

## ADR-012: Go Router for Navigation

**Date**: 2024-09
**Status**: Accepted

**Context**: Need deep linking, type-safe routing, nested navigation.

**Decision**: go_router package (recommended by Flutter team).

**Consequences**:
- ✅ Declarative routing
- ✅ Deep linking support
- ✅ Type-safe navigation
- ✅ Good docs and community

---

## ADR-013: Multi-Language with ARB Files

**Date**: 2024-09
**Status**: Accepted

**Context**: Target users speak English, Hindi, Marathi, Tamil, Telugu.

**Decision**: Flutter's built-in l10n with ARB files.

**Languages**:
- English (en) - default
- Hindi (hi)
- Marathi (mr)
- Tamil (ta)
- Telugu (te)

**Consequences**:
- ✅ Native Flutter support
- ✅ Type-safe translations
- ⚠️ Requires translation for every string
- ⚠️ Must test RTL layouts (future)

---

## ADR-014: Trial Period - 14 Days, Then Downgrade to Free

**Date**: 2024-09
**Status**: Accepted

**Context**: Need to convert users without upfront payment barrier.

**Decision**: 14-day trial of Standard plan. Auto-downgrade to Free if no payment. Send reminders on day 10, 13, 14.

**Consequences**:
- ✅ Low barrier to entry
- ✅ Users experience full product
- ⚠️ Must handle grace period
- ⚠️ Downgrade = data limits

**Free Plan Limits**: 50 products, 100 invoices/mo. Enforced at API level.

---

## ADR-015: Sync Conflict Resolution - Last Write Wins

**Date**: 2024-09
**Status**: Accepted

**Context**: Same record edited offline on two devices creates conflict.

**Decision**: Last-write-wins based on updated_at timestamp. Deep merge for JSONB fields.

**Consequences**:
- ✅ Simple to implement
- ✅ No user intervention needed
- ⚠️ Data loss possible (rare)
- ⚠️ Not suitable for collaborative editing

**Mitigation**: Version conflicts logged in audit_log for debugging.

**Future**: Add conflict UI for critical entities (invoices).

---

## ADR-016: Feature Flags with Percentage Rollout

**Date**: 2024-09
**Status**: Accepted

**Context**: Need to test features with subset of users.

**Decision**: feature_flags table with rollout_percent. Tenant-specific overrides in feature_overrides.

**Consequences**:
- ✅ Gradual rollout
- ✅ A/B testing capable
- ✅ Emergency disable switch
- ⚠️ Must check flags in app + API

**Example**: `stock_predictions` starts at 10%, then 25%, 50%, 100%.

---

## ADR-017: Admin Dashboard - Next.js + shadcn/ui

**Date**: 2024-09
**Status**: Accepted

**Context**: Need admin panel for tenant management and low-code builder.

**Decision**: Next.js 14 App Router with shadcn/ui components.

**Consequences**:
- ✅ Fast development with pre-built components
- ✅ SSR for admin auth
- ✅ Beautiful UI out of the box
- ⚠️ React learning curve for non-FE devs

---

## ADR-018: No Real-Time Sync (Pull-Based Only)

**Date**: 2024-09
**Status**: Accepted

**Context**: Real-time sync adds complexity. Most shops single-user or sequential usage.

**Decision**: Pull-based sync only. No Supabase Realtime subscriptions in v1.

**Consequences**:
- ✅ Simpler implementation
- ✅ Lower battery usage
- ✅ Lower server load
- ⚠️ Stale data possible (max 30s)
- ⚠️ Multi-user shops see delays

**Future**: Add Realtime for Pro plan multi-device shops.

---

## ADR-019: CSV Import for Bulk Data

**Date**: 2024-09
**Status**: Accepted

**Context**: Users migrating from Excel/physical registers need bulk import.

**Decision**: CSV import for products, customers. Map columns to fields.

**Consequences**:
- ✅ Easy migration
- ✅ Bulk data entry
- ⚠️ Must handle encoding (UTF-8)
- ⚠️ Error handling complex

**Format**: First row = headers. Map to entity fields. Validate before import.

---

## ADR-020: Audit Log - Immutable, Append-Only

**Date**: 2024-09
**Status**: Accepted

**Context**: Need compliance and debugging trail.

**Decision**: audit_log table. No updates/deletes. Insert-only via triggers and API.

**Consequences**:
- ✅ Complete history
- ✅ Tamper-proof
- ⚠️ Table grows indefinitely

**Retention**: Archive logs older than 1 year to cold storage.

---

## Future Decisions Needed

- [ ] iOS app timeline
- [ ] Multi-currency support
- [ ] API rate limiting strategy
- [ ] Data export format (GDPR compliance)
- [ ] Disaster recovery & backups
- [ ] Load balancing strategy at scale
- [ ] Database sharding threshold
- [ ] Real-time sync for multi-user (Pro plan)
