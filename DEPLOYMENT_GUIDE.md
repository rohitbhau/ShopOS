# ShopOS Deployment Guide

## Quick Start - Get ShopOS Running in 30 Minutes

### Prerequisites
- Flutter 3.x installed
- Dart 3.x installed
- Supabase account
- Android Studio / Xcode (for mobile builds)
- Git

---

## Step 1: Backend Setup (Supabase)

### 1.1 Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Click "New Project"
3. Name: `shopos-prod`
4. Database password: Save securely
5. Region: Choose closest to India (Asia Mumbai recommended)
6. Wait for project to be ready (~2 minutes)

### 1.2 Run Database Migrations
```bash
cd packages/supabase

# Install Supabase CLI if not already
npm install -g supabase

# Initialize (if needed)
supabase init

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Push migrations
supabase db push

# This will run all 8 migrations:
# - 001_tenants.sql
# - 002_users.sql
# - 003_apps.sql
# - 004_entities.sql
# - 005_records.sql
# - 006_workflows.sql
# - 007_subscriptions.sql
# - 008_rls.sql
```

### 1.3 Deploy Edge Functions
```bash
# Deploy authentication function
supabase functions deploy auth-set-tenant-claim

# Deploy tenant creation function
supabase functions deploy create-tenant

# Deploy template seeding function
supabase functions deploy seed-template
```

### 1.4 Get API Keys
1. Go to project Settings → API
2. Copy:
   - `Project URL` (e.g., https://xxx.supabase.co)
   - `anon/public key`
3. Save these for Step 2

---

## Step 2: Mobile App Setup (Flutter)

### 2.1 Clone and Install Dependencies
```bash
cd apps/mobile

# Install dependencies
flutter pub get

# Generate database code (CRITICAL STEP)
flutter pub run build_runner build --delete-conflicting-outputs

# This generates app_database.g.dart from app_database.dart
```

### 2.2 Configure Environment
Create `apps/mobile/lib/core/config/env.dart`:
```dart
class Environment {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

Or update existing `env.dart` with your keys.

### 2.3 Update Main.dart
Ensure `main.dart` initializes Supabase:
```dart
await Supabase.initialize(
  url: Environment.supabaseUrl,
  anonKey: Environment.supabaseAnonKey,
);
```

### 2.4 Configure Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera permission is required for barcode scanning</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access for invoice sharing</string>
```

### 2.5 Test on Emulator/Device
```bash
# Run on connected device
flutter run

# Or run in debug mode
flutter run --debug

# Or run in release mode
flutter run --release
```

---

## Step 3: Build for Production

### 3.1 Android APK
```bash
cd apps/mobile

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# Or build App Bundle for Play Store
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 3.2 iOS IPA
```bash
cd apps/mobile

# Build iOS release
flutter build ios --release

# Then open Xcode:
# 1. Open ios/Runner.xcworkspace
# 2. Select "Product" → "Archive"
# 3. Distribute to App Store or TestFlight
```

---

## Step 4: Seed Initial Data

### 4.1 Create First Shop (via App)
1. Open app → Login with phone (OTP)
2. Create Shop → Select "Retail Store"
3. Enter shop details
4. Template entities auto-created

### 4.2 Or Seed via API
```bash
# Using curl
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/seed-template' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "tenant_id": "TENANT_UUID",
    "template_type": "retail"
  }'
```

---

## Step 5: Verify Everything Works

### Test Checklist
- [ ] Login with phone OTP works
- [ ] Shop creation works
- [ ] Add product → Product appears in list
- [ ] Add customer → Customer appears in list
- [ ] Generate invoice → Invoice created
- [ ] Check reports → Data shows correctly
- [ ] Turn off WiFi → Add product → Works offline
- [ ] Turn on WiFi → Product syncs to server
- [ ] Logout and login → Data persists

---

## Troubleshooting

### Issue: "app_database.g.dart not found"
**Solution**: Run build_runner
```bash
cd apps/mobile
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: "Supabase initialization failed"
**Solution**: Check API keys in `env.dart`
- Verify URL starts with `https://`
- Verify anon key is correct
- Check internet connection

### Issue: "RLS policy violation"
**Solution**: Verify migrations ran successfully
```bash
supabase db push
# Check for errors in output
```

### Issue: "No internet permission"
**Solution**: Add to AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### Issue: "Camera not working"
**Solution**: 
1. Add camera permission to manifest
2. Request permission at runtime
3. Test on physical device (not emulator)

---

## Production Deployment

### Play Store (Android)
1. Create app listing at [play.google.com/console](https://play.google.com/console)
2. Fill app details, screenshots, description
3. Upload `app-release.aab`
4. Submit for review
5. Wait 1-3 days for approval

### App Store (iOS)
1. Create app in [App Store Connect](https://appstoreconnect.apple.com)
2. Fill app metadata
3. Upload build via Xcode
4. Submit for review
5. Wait 1-3 days for approval

### TestFlight (iOS Beta)
1. Upload build via Xcode
2. Add beta testers via email
3. No review needed for internal testing

---

## Monitoring & Maintenance

### Setup Monitoring
```bash
# Add to pubspec.yaml
dependencies:
  sentry_flutter: ^7.0.0
  firebase_crashlytics: ^3.0.0

# Initialize in main.dart
await SentryFlutter.init((options) {
  options.dsn = 'YOUR_SENTRY_DSN';
});
```

### Database Backups
1. Supabase auto-backups daily
2. Manual backup: Project Settings → Database → Backups
3. Download and store securely

### Update Strategy
1. Increment version in `pubspec.yaml`
2. Build new APK/IPA
3. Upload to stores
4. Users get update notification
5. Test thoroughly before release

---

## Environment Variables (Production)

### Supabase Environment Variables (for Edge Functions)
```env
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJxxx...
SUPABASE_SERVICE_ROLE_KEY=eyJxxx...  # Keep secret!
```

### Flutter Build Flavors (Optional)
Create separate environments for dev/staging/prod:
```bash
# Development
flutter run --flavor dev

# Production
flutter run --flavor prod
```

---

## Performance Optimization

### 1. Enable Code Obfuscation
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

### 2. Reduce App Size
```bash
# Split APKs by ABI
flutter build apk --release --split-per-abi

# Output:
# - app-armeabi-v7a-release.apk (ARM 32-bit)
# - app-arm64-v8a-release.apk (ARM 64-bit)
# - app-x86_64-release.apk (Intel 64-bit)
```

### 3. Enable R8 (Android)
In `android/gradle.properties`:
```properties
android.enableR8=true
android.enableR8.fullMode=true
```

---

## Security Checklist

### Before Production
- [ ] All API keys in environment variables (not hardcoded)
- [ ] RLS policies enabled on all tables
- [ ] Edge function authentication configured
- [ ] SSL/TLS enabled (Supabase default)
- [ ] Input validation on all forms
- [ ] SQL injection prevention (Supabase client handles)
- [ ] XSS prevention (Flutter handles)
- [ ] Secure storage for local data (using flutter_secure_storage)
- [ ] No sensitive data in logs
- [ ] Code obfuscation enabled

---

## Scaling Considerations

### When to Scale Up

**Database** (Supabase):
- Free tier: Up to 500 MB, 50 GB bandwidth
- Pro tier ($25/month): 8 GB, 250 GB bandwidth
- Upgrade when:
  - Database size > 400 MB
  - Bandwidth > 40 GB/month
  - Need better performance

**Edge Functions**:
- Free tier: 500K invocations/month
- Pro tier: 2M invocations/month
- Upgrade when approaching limits

**Mobile App**:
- Optimize sync frequency
- Implement pagination for large lists
- Archive old data (> 6 months)
- Use indexes on Drift tables

---

## Support & Documentation

### For Developers
- Architecture: `docs/architecture.md`
- Offline Mode: `OFFLINE_MODE_GUIDE.md`
- User Guide: `USER_GUIDE.md`
- API Reference: Check Supabase project documentation

### For Users
- Setup Guide: `SETUP.md`
- Quick Start: `QUICKSTART.md`
- Demo Script: `DEMO_SCRIPT.md`

### Getting Help
- GitHub Issues: Create issue with logs
- Supabase Docs: [supabase.com/docs](https://supabase.com/docs)
- Flutter Docs: [flutter.dev/docs](https://flutter.dev/docs)

---

## Post-Deployment Checklist

### Week 1
- [ ] Monitor crash reports daily
- [ ] Check sync errors in logs
- [ ] Verify all edge functions working
- [ ] Test on multiple devices
- [ ] Gather user feedback

### Month 1
- [ ] Analyze usage patterns
- [ ] Optimize slow queries
- [ ] Fix reported bugs
- [ ] Plan feature updates
- [ ] Review database size

### Quarter 1
- [ ] Major version update
- [ ] New features based on feedback
- [ ] Performance improvements
- [ ] Security audit
- [ ] User survey

---

## Success Metrics to Track

### Technical Metrics
- Crash-free rate (target: >99%)
- Average sync time (target: <5s)
- App startup time (target: <2s)
- Database query time (target: <100ms)

### Business Metrics
- Daily active shops
- Invoices generated per day
- Products added per shop
- Customer retention rate

### User Satisfaction
- App Store rating (target: >4.5)
- Support tickets per user
- Feature request frequency
- Churn rate

---

## Congratulations!

ShopOS is now deployed and ready to serve small shops in India. 🎉

For questions or issues, refer to the documentation or create a GitHub issue.

---

*Deployment Guide v1.0*  
*Last Updated: October 1, 2026*
