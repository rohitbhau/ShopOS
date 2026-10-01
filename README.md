# ShopOS - Low-Code Platform for Small Shops

Multi-tenant, offline-first SaaS platform for small shops in India (kirana, pharmacy, salon, restaurant, boutique, repair shops).

## Tech Stack

- **Mobile**: Flutter 3.x, Riverpod 2.x, Drift (SQLite + SQLCipher), Go Router
- **Backend**: Supabase (Postgres + Auth + Storage + Edge Functions + Realtime)
- **Admin**: Next.js 14 + Tailwind + shadcn/ui
- **Payments**: Razorpay
- **Messaging**: WhatsApp Cloud API

## Quick Setup (10 minutes)

### Prerequisites
- Flutter 3.x
- Node.js 18+
- Supabase CLI
- Android Studio (for mobile)

### 1. Clone & Install
```bash
git clone <repo-url> shopos
cd shopos

# Install Flutter dependencies
cd apps/mobile
flutter pub get
cd ../..

# Install Node dependencies
cd apps/admin
npm install
cd ../landing
npm install
cd ../..

# Install shared package
cd packages/shared
npm install
cd ../..
```

### 2. Setup Supabase
```bash
cd packages/supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref <your-project-ref>

# Run migrations
supabase db push

# Deploy edge functions
supabase functions deploy

cd ../..
```

### 3. Configure Environment

Create `.env` files:

**apps/mobile/.env**
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

**apps/admin/.env.local**
```
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

### 4. Run Applications

```bash
# Mobile app (on Android emulator)
cd apps/mobile
flutter run

# Admin dashboard
cd apps/admin
npm run dev

# Landing page
cd apps/landing
npm run dev
```

## Project Structure

```
shopos/
├── apps/
│   ├── mobile/          # Flutter Android app
│   ├── admin/           # Next.js admin dashboard
│   └── landing/         # Next.js landing page
├── packages/
│   ├── supabase/        # Migrations, edge functions, seeds
│   ├── shared/          # TypeScript types & schemas
│   └── docs/            # Documentation
└── .github/workflows/   # CI/CD
```

## Core Features

### Mobile App (Offline-First)
- Phone OTP authentication
- Dynamic low-code forms & entities
- Products & inventory management
- POS billing (works offline)
- Invoice PDF + UPI QR generation
- Customer ledger
- Reports & analytics
- Staff management & permissions
- Subscription billing
- WhatsApp notifications

### Admin Dashboard
- Tenant management
- Low-code entity builder
- Workflow builder
- Template manager
- Subscription management
- Revenue analytics
- Feature flags

### Low-Code Engine
- Dynamic entity schemas (JSON-based)
- Form/list/dashboard renderer
- Computed fields
- Workflow automation
- Custom field types

## Subscription Plans

| Plan | Price | Features |
|------|-------|----------|
| Free | ₹0 | 1 shop, 1 user, 50 products, 100 invoices/mo |
| Basic | ₹149/mo | 1 shop, 3 users, 1000 products, unlimited invoices |
| Standard | ₹299/mo | 1 shop, 10 users, WhatsApp, loyalty, advanced reports |
| Pro | ₹599/mo | 3 shops, API, custom domain, priority support |

## Development

### Run Tests
```bash
# Flutter tests
cd apps/mobile
flutter test
flutter test integration_test

# Admin tests
cd apps/admin
npm test
```

### Build for Production
```bash
# Android APK
cd apps/mobile
flutter build apk --release

# Android AAB (Play Store)
flutter build appbundle --release

# Admin dashboard
cd apps/admin
npm run build

# Landing page
cd apps/landing
npm run build
```

## Documentation

- [Architecture](packages/docs/architecture.md)
- [API Reference](packages/docs/api.md)
- [User Guide](packages/docs/user_guide.md)
- [Operations Runbook](packages/docs/ops_runbook.md)
- [Decisions Log](packages/docs/decisions.md)

## Support

- WhatsApp: +91-XXXXXXXXXX
- Email: support@shopos.app
- Docs: https://docs.shopos.app

## License

Proprietary - All rights reserved
