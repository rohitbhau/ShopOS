# ShopOS - Development Setup Guide

Complete setup instructions to get ShopOS running locally in under 30 minutes.

## Prerequisites

### Required Software
- **Flutter SDK**: 3.19.0 or higher
- **Dart SDK**: 3.3.0 or higher (included with Flutter)
- **Node.js**: 18.x or higher
- **npm** or **pnpm**: Latest version
- **Supabase CLI**: Latest version
- **Android Studio**: Latest version (for mobile development)
- **Git**: Latest version

### Optional but Recommended
- **VS Code** with Flutter + Dart extensions
- **Android Emulator** (Pixel 5 API 34 recommended)
- **Physical Android device** for testing (min SDK 24)

---

## Step 1: Clone Repository

```bash
git clone <repository-url> shopos
cd shopos
```

---

## Step 2: Supabase Setup

### 2.1 Install Supabase CLI

#### macOS
```bash
brew install supabase/tap/supabase
```

#### Windows
```powershell
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

#### Linux
```bash
brew install supabase/tap/supabase
```

### 2.2 Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Sign up / Log in
3. Click "New Project"
4. Fill in:
   - **Name**: shopos-dev (or your choice)
   - **Database Password**: Generate strong password (save it!)
   - **Region**: Choose closest to India (Mumbai if available)
   - **Pricing Plan**: Free tier (sufficient for development)
5. Wait for project provisioning (~2 minutes)

### 2.3 Link Local Project

```bash
cd packages/supabase

# Login to Supabase CLI
supabase login

# Link to your project
supabase link --project-ref <your-project-ref>
# Find project ref in project URL: https://app.supabase.com/project/<ref>
```

### 2.4 Run Migrations

```bash
# Push all migrations to Supabase
supabase db push

# Verify migrations
supabase db diff --use-migra
```

Expected output: All 8 migrations applied successfully.

### 2.5 Deploy Edge Functions

```bash
# Deploy all edge functions
supabase functions deploy auth-set-tenant-claim
supabase functions deploy create-tenant
# Add remaining functions as they're implemented

# Verify deployments
supabase functions list
```

### 2.6 Get API Keys

1. Go to Project Settings → API
2. Copy:
   - **Project URL**: `https://<ref>.supabase.co`
   - **anon/public key**: Starts with `eyJ...`
   - **service_role key**: Starts with `eyJ...` (keep secret!)

---

## Step 3: Flutter Mobile App Setup

### 3.1 Install Dependencies

```bash
cd apps/mobile

# Get Flutter packages
flutter pub get

# Run code generation (for Drift, Freezed, Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3.2 Configure Environment

Create `.env` file in `apps/mobile/`:

```env
SUPABASE_URL=https://<your-ref>.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here

RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
RAZORPAY_KEY_SECRET=your-secret-here

WHATSAPP_ACCESS_TOKEN=your-token-here
WHATSAPP_PHONE_NUMBER_ID=your-phone-id-here

PRODUCTION=false
APP_VERSION=1.0.0
```

**⚠️ Important**: Never commit `.env` to git. Already in `.gitignore`.

### 3.3 Android Setup

#### Update `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        applicationId "com.shopos.app"
        minSdkVersion 24  // Required for SQLCipher
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

#### Add Permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- Internet -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- Camera for barcode scanning -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- Bluetooth for thermal printer -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    
    <!-- Storage for PDF/CSV export -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    
    <!-- Notifications -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <application>
        ...
    </application>
</manifest>
```

### 3.4 Run the App

```bash
# Check connected devices
flutter devices

# Run on emulator or device
flutter run

# Or with hot reload
flutter run --debug

# Or release mode
flutter run --release
```

Expected: App launches, shows splash, then login screen.

---

## Step 4: Admin Dashboard Setup

### 4.1 Install Dependencies

```bash
cd apps/admin

# Install packages
npm install
# or
pnpm install
```

### 4.2 Configure Environment

Create `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://<your-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=generate-random-secret-here
```

Generate `NEXTAUTH_SECRET`:
```bash
openssl rand -base64 32
```

### 4.3 Run Development Server

```bash
npm run dev
# or
pnpm dev
```

Visit: `http://localhost:3000`

---

## Step 5: Landing Page Setup

### 5.1 Install Dependencies

```bash
cd apps/landing
npm install
```

### 5.2 Run Development Server

```bash
npm run dev
```

Visit: `http://localhost:3001` (or next available port)

---

## Step 6: Verify Setup

### 6.1 Database Health Check

```bash
cd packages/supabase

# Check migrations
supabase db diff --use-migra
# Should show: No schema differences

# Query tenants table
supabase db query "SELECT * FROM tenants LIMIT 1;"
# Should return: (0 rows)
```

### 6.2 Flutter App Health Check

```bash
cd apps/mobile

# Run analyzer
flutter analyze
# Should show: No issues found!

# Run tests
flutter test
# (Will run once tests are implemented)

# Check dependencies
flutter doctor -v
# Should show all ✓ checks
```

### 6.3 Admin Dashboard Health Check

```bash
cd apps/admin

# Run linter
npm run lint
# Should show: No errors

# Type check
npm run type-check
# Should show: No errors
```

---

## Step 7: Add Sample Data (Optional)

### 7.1 Create Test Tenant

Using Supabase SQL Editor:

```sql
-- Create test tenant
INSERT INTO tenants (name, shop_type, phone, plan)
VALUES ('Test Kirana Store', 'retail', '+919876543210', 'free')
RETURNING *;

-- Note the tenant ID from output
```

### 7.2 Create Test User

1. Go to Supabase Dashboard → Authentication → Users
2. Click "Add User"
3. Enter phone: `+919876543210`
4. Password: Generate or use test password
5. Click "Create User"

### 7.3 Link User to Tenant

```sql
-- Get user ID from auth.users
SELECT id, phone FROM auth.users WHERE phone = '+919876543210';

-- Create membership
INSERT INTO memberships (tenant_id, user_id, role)
VALUES (
    '<tenant-id-from-step-7.1>',
    '<user-id-from-auth.users>',
    'owner'
);
```

### 7.4 Test Login

1. Open Flutter app
2. Enter phone: `+919876543210`
3. Request OTP
4. Enter OTP from Supabase Dashboard → Authentication → Users → View user
5. Should log in successfully

---

## Step 8: Configure Razorpay (Production Only)

### 8.1 Create Razorpay Account

1. Go to [razorpay.com](https://razorpay.com)
2. Sign up for business account
3. Complete KYC (requires business documents)

### 8.2 Get API Keys

1. Dashboard → Settings → API Keys
2. Generate keys (Test mode for development)
3. Copy Key ID and Key Secret

### 8.3 Create Subscription Plans

```bash
# Using Razorpay API
curl -X POST https://api.razorpay.com/v1/plans \
  -u <key_id>:<key_secret> \
  -H "Content-Type: application/json" \
  -d '{
    "period": "monthly",
    "interval": 1,
    "item": {
      "name": "ShopOS Basic Plan",
      "amount": 14900,
      "currency": "INR"
    }
  }'
```

Repeat for Standard (29900) and Pro (59900) plans.

---

## Step 9: Configure WhatsApp Cloud API (Production Only)

### 9.1 Create Meta Business Account

1. Go to [developers.facebook.com](https://developers.facebook.com)
2. Create app → Business → WhatsApp
3. Complete business verification (takes 1-2 weeks)

### 9.2 Get Access Token

1. WhatsApp → Getting Started
2. Copy temporary access token (valid 24h)
3. For production, generate permanent token

### 9.3 Add Phone Number

1. WhatsApp → Phone Numbers
2. Add and verify business phone number

### 9.4 Register Message Templates

Go to WhatsApp → Message Templates, create:

1. **low_stock_alert**
```
Product {{1}} is low on stock. Current stock: {{2}}. Minimum: {{3}}.
```

2. **invoice_ready**
```
Thank you for shopping at {{1}}! Your invoice #{{2}} for ₹{{3}} is ready.
```

3. **trial_ending**
```
Your ShopOS trial ends in {{1}} days. Upgrade now to continue: https://shopos.app/plans
```

Approval takes 24-48 hours.

---

## Troubleshooting

### Flutter Issues

#### Build fails with "SDK version"
```bash
# Check Flutter version
flutter --version

# Upgrade if needed
flutter upgrade
```

#### Drift code generation fails
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### Android build fails
```bash
# Check Android SDK
flutter doctor -v

# Accept licenses
flutter doctor --android-licenses
```

### Supabase Issues

#### Migrations fail
```bash
# Reset database (WARNING: deletes all data)
supabase db reset

# Re-run migrations
supabase db push
```

#### Edge function deploy fails
```bash
# Check function logs
supabase functions logs <function-name>

# Redeploy with verbose
supabase functions deploy <function-name> --debug
```

#### RLS policies blocking queries
```sql
-- Temporarily disable RLS (development only)
ALTER TABLE <table-name> DISABLE ROW LEVEL SECURITY;

-- Re-enable after debugging
ALTER TABLE <table-name> ENABLE ROW LEVEL SECURITY;
```

### Network Issues

#### Supabase connection timeout
```bash
# Check internet
ping supabase.com

# Check Supabase status
curl https://<your-ref>.supabase.co/rest/v1/
```

#### Emulator can't reach localhost
```
# Use 10.0.2.2 instead of localhost in Android emulator
SUPABASE_URL=http://10.0.2.2:54321
```

---

## Development Workflow

### 1. Start All Services

```bash
# Terminal 1: Flutter app
cd apps/mobile
flutter run

# Terminal 2: Admin dashboard
cd apps/admin
npm run dev

# Terminal 3: Landing page
cd apps/landing
npm run dev

# Terminal 4: Supabase logs
cd packages/supabase
supabase functions logs --follow
```

### 2. Making Changes

#### Database Changes
```bash
cd packages/supabase

# Create new migration
supabase migration new <migration_name>

# Edit migration file
# Then push
supabase db push
```

#### Flutter Code Changes
- Hot reload: Press `r` in terminal
- Hot restart: Press `R`
- Quit: Press `q`

#### Next.js Changes
- Auto-reloads on file save

### 3. Testing

```bash
# Flutter unit tests
cd apps/mobile
flutter test

# Flutter widget tests
flutter test test/widgets/

# Flutter integration tests
flutter test integration_test/

# Admin tests
cd apps/admin
npm test
```

### 4. Linting & Formatting

```bash
# Flutter
cd apps/mobile
flutter analyze
dart format lib/

# Next.js
cd apps/admin
npm run lint
npm run format
```

---

## Production Deployment

### Flutter App

```bash
cd apps/mobile

# Build APK (for testing)
flutter build apk --release

# Build AAB (for Play Store)
flutter build appbundle --release
```

Files at:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

### Admin & Landing

```bash
# Push to GitHub
git push origin main

# Vercel auto-deploys on push
# Or manual deploy:
cd apps/admin
vercel --prod

cd apps/landing
vercel --prod
```

---

## Useful Commands

### Flutter
```bash
flutter doctor             # Check setup
flutter pub get            # Install dependencies
flutter clean              # Clean build cache
flutter pub upgrade        # Upgrade packages
flutter build apk          # Build APK
flutter logs               # View device logs
```

### Supabase
```bash
supabase status            # Check local status
supabase db reset          # Reset database
supabase db push           # Push migrations
supabase functions list    # List functions
supabase logs              # View logs
```

### Git
```bash
git status                 # Check changes
git add .                  # Stage all
git commit -m "message"    # Commit
git push                   # Push to remote
```

---

## Support

- **Documentation**: `packages/docs/`
- **GitHub Issues**: `<repo-url>/issues`
- **Email**: dev@shopos.app

---

*Last Updated: September 29, 2026*
