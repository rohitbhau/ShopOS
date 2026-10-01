# ShopOS - Quick Start Guide (5 Minutes)

Get ShopOS running in 5 minutes for testing/demo purposes.

---

## Prerequisites Check ✅

Before starting, verify you have:
- [ ] Flutter SDK installed (`flutter --version`)
- [ ] Dart installed (`dart --version`)
- [ ] Supabase account (free tier is fine)
- [ ] Device/emulator ready

---

## Step 1: Supabase Setup (2 minutes)

### 1.1 Create Project
1. Go to [supabase.com](https://supabase.com) → New Project
2. Name: `shopos-demo`
3. Database password: (save it)
4. Region: Asia Mumbai
5. Wait ~2 min for project to be ready

### 1.2 Run Migrations
```bash
cd packages/supabase

# Install Supabase CLI (if not already)
npm install -g supabase

# Link to your project
supabase link --project-ref <YOUR_PROJECT_REF>

# Push all 8 migrations
supabase db push
```

### 1.3 Deploy Functions
```bash
supabase functions deploy auth-set-tenant-claim
supabase functions deploy create-tenant  
supabase functions deploy seed-template
```

### 1.4 Get API Keys
1. Go to Project Settings → API
2. Copy:
   - Project URL
   - anon/public key

---

## Step 2: Flutter Setup (2 minutes)

### 2.1 Install & Generate
```bash
cd apps/mobile

# Install dependencies
flutter pub get

# CRITICAL: Generate database code
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2.2 Configure Keys
Update `lib/core/config/env.dart`:
```dart
class Environment {
  static const String supabaseUrl = 'YOUR_URL_HERE';
  static const String supabaseAnonKey = 'YOUR_KEY_HERE';
}
```

---

## Step 3: Run App (1 minute)

```bash
# Make sure device/emulator is connected
flutter devices

# Run app
flutter run --release
```

**Done!** 🎉

---

## Quick Test Flow

### Test 1: Login
1. Enter phone: `+919876543210`
2. Enter OTP: `123456` (test mode)
3. Should reach shop creation screen

### Test 2: Create Shop
1. Select "Retail Store"
2. Name: "Test Shop"
3. Phone: `9876543210`
4. Tap Create
5. Should create shop and show dashboard

### Test 3: Add Product
1. Tap Products tab
2. Tap + button
3. Fill:
   - Name: "Test Product"
   - Price: 100
   - Stock: 50
4. Tap Save
5. Product should appear in list

### Test 4: Generate Invoice
1. Tap Billing tab
2. Search "Test Product"
3. Tap to add to cart
4. Select payment mode: Cash
5. Tap "Generate Invoice"
6. Invoice should be created

### Test 5: Offline Mode
1. Turn off WiFi
2. Add another product
3. Product should save locally
4. Turn on WiFi
5. Should auto-sync

---

## Troubleshooting

### "app_database.g.dart not found"
```bash
cd apps/mobile
flutter pub run build_runner build --delete-conflicting-outputs
```

### "Supabase not initialized"
- Check `env.dart` has correct URL and key
- Ensure URL starts with `https://`

### "No connected devices"
```bash
# For Android emulator
flutter emulators --launch <emulator_id>

# For iOS simulator
open -a Simulator
```

### "Build failed"
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

---

## Next Steps

After quick start works:
1. Read [FINAL_SUMMARY.md](./FINAL_SUMMARY.md) for complete overview
2. Check [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for production deployment
3. Explore [OFFLINE_MODE_GUIDE.md](./OFFLINE_MODE_GUIDE.md) for architecture details
4. Review [USER_GUIDE.md](./USER_GUIDE.md) for end-user features

---

## Demo Credentials

For testing, use these:
- **Phone**: Any 10-digit number
- **OTP**: `123456` (in test mode)
- **Shop Types**: Retail, Grocery, Restaurant, Medical, Electronics, Services

---

## Quick Commands Reference

```bash
# Run app
flutter run

# Build APK
flutter build apk --release

# Clean build
flutter clean && flutter pub get

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Check for issues
flutter analyze

# Format code
flutter format .

# Run migrations
cd packages/supabase && supabase db push

# Deploy function
supabase functions deploy <function-name>
```

---

## Support

If stuck:
1. Check error message
2. Run `flutter doctor` to verify setup
3. Check [README.md](./README.md) for detailed docs
4. Create GitHub issue with logs

---

**You're ready to explore ShopOS!** 🚀

*Quick Start Guide - October 1, 2026*
