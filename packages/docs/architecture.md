# ShopOS - System Architecture

Comprehensive technical architecture documentation.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Principles](#architecture-principles)
3. [High-Level Architecture](#high-level-architecture)
4. [Data Flow](#data-flow)
5. [Security Architecture](#security-architecture)
6. [Scalability Strategy](#scalability-strategy)
7. [Technology Stack](#technology-stack)
8. [Database Schema](#database-schema)
9. [API Design](#api-design)
10. [Offline-First Strategy](#offline-first-strategy)

---

## System Overview

ShopOS is a multi-tenant, offline-first, low-code SaaS platform designed for small shops in India. The system enables shop owners to manage billing, inventory, customers, and reports from a mobile device, even without internet connectivity.

### Key Characteristics

- **Multi-Tenant**: Single infrastructure serving multiple isolated tenants
- **Offline-First**: Core features work without internet
- **Low-Code**: Dynamic entity schemas enable customization without code
- **Mobile-First**: Optimized for Android smartphones
- **Cost-Effective**: Infrastructure cost < ₹100/tenant/month at scale

---

## Architecture Principles

### 1. Offline-First
Every mutation writes to local database first, then syncs to server asynchronously. This ensures the app works in areas with poor connectivity.

### 2. Multi-Tenancy with RLS
Database-level tenant isolation using Supabase Row-Level Security (RLS). JWT tokens contain `tenant_id` custom claim, enforced at database level.

### 3. Low-Code via JSONB
Entity schemas stored as JSON. All records stored as JSONB in a single `records` table. GIN indexes enable fast queries.

### 4. Progressive Enhancement
Basic features work on low-end devices. Advanced features (voice input, ML predictions) enhance experience on capable devices.

### 5. Security by Default
- All data encrypted at rest (SQLCipher)
- TLS for all network communication
- RLS enforces data isolation
- No secrets in client code
- Webhook signature verification

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        End Users                             │
│  (Shop Owners, Staff, Customers)                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Client Layer                             │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  Flutter Mobile  │  │   Next.js Admin  │                │
│  │   (Android)      │  │   (React SSR)    │                │
│  └──────────────────┘  └──────────────────┘                │
│          │                      │                            │
│   ┌──────▼──────┐              │                            │
│   │  Drift DB   │              │                            │
│   │ (SQLite +   │              │                            │
│   │ SQLCipher)  │              │                            │
│   └─────────────┘              │                            │
└────────────────────────────────┼────────────────────────────┘
                                 │
                                 │ REST + Realtime (optional)
                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                   Backend Layer                              │
├─────────────────────────────────────────────────────────────┤
│                      Supabase BaaS                           │
│  ┌────────────┬─────────────┬─────────────┬──────────────┐ │
│  │ PostgreSQL │ Auth (JWT)  │ Storage     │ Edge         │ │
│  │ (w/ RLS)   │ (Phone OTP) │ (S3-compat) │ Functions    │ │
│  │            │             │             │ (Deno)       │ │
│  └────────────┴─────────────┴─────────────┴──────────────┘ │
└─────────────────────────────────────────────────────────────┘
                                 │
                   ┌─────────────┼─────────────┐
                   │             │             │
                   ▼             ▼             ▼
         ┌─────────────┐ ┌─────────────┐ ┌──────────────┐
         │  Razorpay   │ │  WhatsApp   │ │   Vercel     │
         │  (Payments) │ │  Cloud API  │ │  (Hosting)   │
         └─────────────┘ └─────────────┘ └──────────────┘
```

---

## Data Flow

### 1. User Authentication Flow

```
User → Enter Phone → Edge Function (send OTP) → SMS Gateway
                                                      ↓
User ← Verify OTP ← Edge Function (verify + create session)
                          ↓
                    Generate JWT with:
                    - user_id
                    - tenant_id (from memberships)
                    - role
                          ↓
                    Return to client
                          ↓
                    Store in secure storage
```

### 2. Offline Mutation Flow

```
User Action (e.g., create invoice)
          ↓
   Write to Drift local DB
          ↓
   Insert into outbox table (queued_actions)
          ↓
   Return success to UI immediately
          ↓
   [Background] Sync engine runs (every 30s)
          ↓
   Process queued actions in order
          ↓
   POST to Supabase (with JWT)
          ↓
   RLS verifies tenant_id
          ↓
   Insert/Update in records table
          ↓
   Mark action as synced in outbox
          ↓
   Update UI sync status
```

### 3. Online Query Flow

```
User requests data (e.g., reports)
          ↓
   Check local cache (Drift)
          ↓
   If stale, fetch from Supabase
          ↓
   GET /records?entity_id=...&tenant_id=...
          ↓
   RLS filters by tenant_id automatically
          ↓
   Return JSON data
          ↓
   Deserialize via low-code engine
          ↓
   Render dynamic UI
```

---

## Security Architecture

### 1. Authentication & Authorization

**Authentication**:
- Phone OTP via Supabase Auth
- JWT tokens (1 hour expiry, auto-refresh)
- Secure storage via flutter_secure_storage

**Authorization**:
- Role-based: Owner, Manager, Cashier, Viewer
- Enforced at:
  - Database level (RLS policies)
  - API level (edge functions)
  - Client level (UI visibility)

### 2. Data Encryption

**At Rest**:
- Supabase: AES-256 encryption (default)
- Mobile: SQLCipher with AES-256
- Key derived from device ID + user PIN

**In Transit**:
- TLS 1.3 for all connections
- Certificate pinning (optional, for paranoid mode)

### 3. Tenant Isolation

**Database Level**:
```sql
-- RLS policy example
CREATE POLICY records_isolation ON records
FOR ALL
USING (tenant_id = auth.tenant_id())
WITH CHECK (tenant_id = auth.tenant_id());
```

**API Level**:
- All queries automatically filtered by `tenant_id`
- Cross-tenant queries blocked
- Service role key used only in edge functions (server-side)

### 4. Webhook Security

- HMAC signature verification
- Timestamp validation (reject if > 5 min old)
- IP allowlisting (Razorpay, Meta)

**Example**:
```typescript
const signature = req.headers.get('X-Razorpay-Signature');
const payload = await req.text();
const expectedSignature = createHmac('sha256', secret)
  .update(payload)
  .digest('hex');
if (signature !== expectedSignature) {
  throw new Error('Invalid signature');
}
```

---

## Scalability Strategy

### Current Setup (< 1,000 tenants)

- **Database**: Supabase Pro (shared Postgres)
- **Storage**: Supabase Storage (S3-compatible)
- **Compute**: Edge functions (auto-scale)
- **Expected Load**: ~100 req/sec peak

### Scale to 10,000 tenants

- **Database**: Dedicated Postgres instance
- **Read Replicas**: 2x for reports/analytics
- **CDN**: CloudFlare for static assets
- **Caching**: Redis for hot data
- **Expected Load**: ~1,000 req/sec peak

### Scale to 100,000+ tenants (Future)

- **Database Sharding**:
  - Shard by `tenant_id` hash
  - 10 shards = 10K tenants each
- **Separate Analytics DB**:
  - Snowflake/ClickHouse for OLAP queries
  - Daily ETL from OLTP
- **Microservices**:
  - Billing service (high write)
  - Reports service (read-heavy)
  - Notification service (async)
- **Message Queue**:
  - RabbitMQ/SQS for async tasks
  - Workflow orchestration

---

## Technology Stack

### Mobile App
- **Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **State Management**: Riverpod 2.x
- **Local DB**: Drift (SQLite) + SQLCipher
- **Navigation**: go_router
- **Network**: Supabase client, http
- **PDF**: pdf + printing packages
- **Barcode**: mobile_scanner
- **Charts**: fl_chart
- **Payments**: razorpay_flutter

### Backend
- **BaaS**: Supabase (Postgres + Auth + Storage + Functions)
- **Database**: PostgreSQL 15
- **Functions Runtime**: Deno (V8 isolates)
- **Language**: TypeScript
- **ORM**: Supabase client (auto-generated)

### Admin Dashboard
- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **UI Library**: shadcn/ui (Radix + Tailwind)
- **Forms**: React Hook Form + Zod
- **Charts**: Recharts
- **DnD**: @dnd-kit
- **State**: Zustand (minimal)

### Infrastructure
- **Hosting**: Vercel (Next.js), Supabase (backend)
- **CDN**: Vercel Edge Network, Supabase CDN
- **DNS**: Cloudflare
- **Monitoring**: Sentry (errors), PostHog (analytics)
- **CI/CD**: GitHub Actions

### External Services
- **Payments**: Razorpay
- **Messaging**: WhatsApp Cloud API (Meta)
- **SMS**: Twilio (backup)
- **Email**: SendGrid (transactional)

---

## Database Schema

### Core Tables

#### tenants
Multi-tenant isolation root.
```sql
- id: uuid (PK)
- name: text (shop name)
- shop_type: enum (retail, pharmacy, salon, etc.)
- phone: text
- address: jsonb
- gstin: text
- logo_url: text
- plan: enum (free, basic, standard, pro)
- trial_ends_at: timestamptz
- is_active: boolean
- created_at, updated_at: timestamptz
```

#### profiles
User profiles (extends auth.users).
```sql
- id: uuid (PK, FK to auth.users)
- phone: text (unique)
- name: text
- locale: enum (en, hi, mr, ta, te)
- created_at, updated_at: timestamptz
```

#### memberships
Links users to tenants with roles.
```sql
- id: uuid (PK)
- tenant_id: uuid (FK to tenants)
- user_id: uuid (FK to profiles)
- role: enum (owner, manager, cashier, viewer)
- is_active: boolean
- created_at, updated_at: timestamptz
- UNIQUE(tenant_id, user_id)
```

#### apps
Low-code apps within tenants.
```sql
- id: uuid (PK)
- tenant_id: uuid (FK to tenants)
- name: text
- template_key: text (retail, pharmacy, etc.)
- config: jsonb
- is_active: boolean
- created_at, updated_at: timestamptz
```

#### entities
Dynamic entity schemas (low-code core).
```sql
- id: uuid (PK)
- app_id: uuid (FK to apps)
- name: text (product, customer, etc.)
- label: text (Product, Customer, etc.)
- icon: text
- schema: jsonb (field definitions)
- is_system: boolean
- display_order: int
- created_at, updated_at: timestamptz
- UNIQUE(app_id, name)
```

#### records
All dynamic data (low-code core).
```sql
- id: uuid (PK)
- tenant_id: uuid (FK to tenants)
- entity_id: uuid (FK to entities)
- data: jsonb (the actual record data)
- created_by: uuid (FK to profiles)
- created_at, updated_at, deleted_at: timestamptz
- INDEX (tenant_id, entity_id, deleted_at)
- GIN INDEX (data jsonb_path_ops)
```

### Workflow Tables

#### workflows
Automation definitions.
```sql
- id: uuid (PK)
- app_id: uuid (FK to apps)
- name: text
- description: text
- trigger: jsonb (event definition)
- conditions: jsonb (when to fire)
- actions: jsonb (what to do)
- is_active: boolean
- execution_count: int
- last_executed_at: timestamptz
- created_at, updated_at: timestamptz
```

### Billing Tables

#### subscriptions
SaaS subscriptions (Razorpay).
```sql
- id: uuid (PK)
- tenant_id: uuid (FK to tenants)
- plan: enum
- status: enum (active, trialing, past_due, cancelled, halted)
- razorpay_sub_id: text (unique)
- razorpay_customer_id: text
- current_period_start, current_period_end: timestamptz
- cancel_at_period_end: boolean
- cancelled_at: timestamptz
- created_at, updated_at: timestamptz
```

#### invoices_saas
SaaS billing invoices (not shop invoices).
```sql
- id: uuid (PK)
- tenant_id: uuid (FK to tenants)
- subscription_id: uuid (FK to subscriptions)
- amount_paise: int
- status: enum (draft, pending, paid, failed, refunded)
- razorpay_payment_id: text
- razorpay_order_id: text
- invoice_number: text (unique)
- due_date, paid_at: timestamptz
- created_at, updated_at: timestamptz
```

### Audit Table

#### audit_log
Immutable append-only log.
```sql
- id: bigserial (PK)
- tenant_id: uuid
- user_id: uuid
- action: text (auth.login, record.created, etc.)
- entity: text
- record_id: uuid
- diff: jsonb (before/after)
- metadata: jsonb
- ip_address: inet
- user_agent: text
- created_at: timestamptz
- INDEX (tenant_id, created_at DESC)
- GIN INDEX (metadata)
```

---

## API Design

### REST Endpoints (via Supabase)

Base URL: `https://<project-ref>.supabase.co/rest/v1/`

#### Authentication
```
POST /auth/v1/signup         # Phone OTP signup
POST /auth/v1/verify         # Verify OTP
POST /auth/v1/token?grant_type=refresh_token  # Refresh JWT
POST /auth/v1/logout         # Logout
```

#### Records (Dynamic Entities)
```
GET    /records?entity_id=eq.<uuid>&tenant_id=eq.<uuid>  # List
POST   /records                                           # Create
PATCH  /records?id=eq.<uuid>                             # Update
DELETE /records?id=eq.<uuid>                             # Delete (soft)
```

**Example**: Get all products
```
GET /records?entity_id=eq.<product-entity-id>&tenant_id=eq.<tenant-id>&deleted_at=is.null
Authorization: Bearer <jwt>
```

### Edge Functions

Base URL: `https://<project-ref>.supabase.co/functions/v1/`

#### Auth
```
POST /auth-set-tenant-claim     # Called on login, returns JWT claims
```

#### Tenant Management
```
POST /create-tenant             # Create tenant + app + membership
  Body: { name, shop_type, template_key }
POST /seed-template             # Populate entities from template
  Body: { app_id, template_key }
```

#### Workflows
```
POST /run-workflow              # Execute workflow manually
  Body: { workflow_id, trigger_data }
```

#### Integrations
```
POST /send-whatsapp             # Send WhatsApp message
  Body: { to, template, variables, attachment }
POST /whatsapp-webhook          # Receive WhatsApp events (webhook)
POST /razorpay-webhook          # Receive Razorpay events (webhook)
```

#### Scheduled
```
POST /daily-summary             # Cron: Send daily sales summary (9 PM IST)
POST /trial-reminder            # Cron: Send trial ending reminders (10 AM IST)
```

---

## Offline-First Strategy

### Core Principles

1. **Local-First Writes**: All mutations write to Drift local DB first
2. **Outbox Pattern**: Queue actions for background sync
3. **Eventual Consistency**: Accept that data may be stale
4. **Conflict Resolution**: Last-write-wins with deep merge

### Implementation

#### Local Database (Drift)

Tables mirror server schema + sync metadata:
```dart
@DriftDatabase(tables: [
  Products, Customers, Invoices,
  QueuedActions, SyncMetadata, SyncConflicts
])
class AppDatabase extends _$AppDatabase {
  // DAOs for CRUD operations
}
```

#### Outbox Table

```dart
class QueuedActions extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()();
  TextColumn get action => text()(); // create, update, delete
  TextColumn get payload => text()(); // JSON
  TextColumn get status => text()(); // pending, syncing, synced, failed
  IntColumn get retryCount => integer()();
  DateTimeColumn get createdAt => dateTime()();
}
```

#### Sync Engine

```dart
class SyncEngine {
  Future<void> syncNow() async {
    // 1. Check connectivity
    // 2. Push queued actions (create, update, delete)
    // 3. Pull changes since last sync
    // 4. Resolve conflicts (if any)
    // 5. Update sync status
  }
}
```

**Frequency**: Every 30 seconds + on connectivity change

#### Conflict Resolution

```dart
Map<String, dynamic> resolve(local, remote) {
  // Compare updated_at timestamps
  // If local newer → use local
  // If remote newer → use remote
  // If equal → deep merge JSONB fields
}
```

### Offline Capabilities

| Feature | Offline | Notes |
|---------|---------|-------|
| Billing | ✅ Yes | Full POS, invoice generation |
| Print Receipt | ✅ Yes | Via Bluetooth thermal printer |
| Add Products | ✅ Yes | Syncs when online |
| Edit Products | ✅ Yes | Conflict resolution on sync |
| View Reports | ✅ Yes | Local data only |
| Add Customers | ✅ Yes | Syncs when online |
| Barcode Scan | ✅ Yes | Camera-based, no network |
| UPI Payment | ❌ No | Requires internet for QR generation |
| WhatsApp Notifications | ❌ No | Queued, sent when online |
| Subscription Renewal | ❌ No | Requires Razorpay API |

---

## Monitoring & Observability

### Error Tracking
- **Tool**: Sentry
- **Events**: Exceptions, ANRs, crashes
- **Alerts**: Slack + Email for P0/P1 errors

### Analytics
- **Tool**: PostHog
- **Events**: User actions, feature usage, funnel tracking
- **Dashboards**: Real-time usage, cohort retention

### Performance
- **Flutter**: Performance overlay in debug mode
- **Backend**: Supabase dashboard (query performance, slow queries)
- **Alerts**: P95 latency > 500ms

### Uptime
- **Tool**: UptimeRobot
- **Monitors**: API health, edge functions, website
- **Alerts**: SMS + Slack if down > 2 minutes

---

## Disaster Recovery

### Backup Strategy

**Database**:
- Supabase: Daily automated backups (7-day retention)
- Manual backups before major migrations
- Point-in-time recovery (PITR) enabled

**Storage**:
- Supabase Storage: S3 cross-region replication
- User-uploaded files: 30-day retention after delete

**Mobile**:
- User-initiated cloud backup (Settings → Backup)
- Encrypted with user-specific key
- Stored in Supabase Storage

### Recovery Scenarios

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| Database corruption | 1 hour | 24 hours | Restore from daily backup |
| Edge function failure | 5 min | 0 | Auto-redeploy via CI/CD |
| Complete data loss | 4 hours | 24 hours | Restore from Supabase backup |
| Tenant data deleted | 1 hour | 0 | Restore from PITR |

---

## Future Architecture Considerations

### Phase 2 (6-12 months)
- Real-time sync via Supabase Realtime
- Multi-device conflict UI
- Voice input for billing
- ML-based stock predictions

### Phase 3 (12-24 months)
- iOS app
- Desktop PWA
- API for third-party integrations
- Multi-currency support
- Multi-shop management

### Phase 4 (24+ months)
- Marketplace (plugins by developers)
- White-label solution for POS vendors
- Enterprise plan (10,000+ employees)
- Global expansion (SEA, Africa, LatAm)

---

*Last Updated: September 29, 2026*  
*Version: 1.0*
