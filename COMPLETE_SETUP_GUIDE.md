# ShopOS Mobile - Complete Setup Guide
## Zero Errors, Perfect Flow

---

## 🎯 What You'll Achieve

After following this guide:
- ✅ Database fully configured
- ✅ Authentication working perfectly
- ✅ Shop creation functional
- ✅ Logout from anywhere
- ✅ Complete user flow working
- ✅ **ZERO ERRORS**

---

## 📋 Prerequisites

You have:
- ✅ Supabase project: `https://dmqsutuniayqtfsaxjuq.supabase.co`
- ✅ Anon key: `sb_publishable_Na2Ql0HkKp9enLLBWYTOsQ_sJx9GnIr`
- ✅ Database credentials:
  - Host: `db.dmqsutuniayqtfsaxjuq.supabase.co`
  - Port: `5432`
  - Database: `postgres`
  - User: `postgres`
- ✅ Flutter project at: `c:\Users\rohit\Downloads\ShopOS\apps\mobile`

---

## 🚀 Setup Steps (15 minutes total)

### STEP 1: Disable Email Confirmation (2 minutes)

**Why**: So users can signup and login immediately without email verification.

1. Go to: https://dmqsutuniayqtfsaxjuq.supabase.co
2. Click **Authentication** (left sidebar)
3. Click **Settings**
4. Scroll to **"Email Auth"** section
5. Find **"Enable email confirmations"** toggle
6. **Turn it OFF** ❌
7. Click **Save** at bottom

✅ **Done!** Users can now signup instantly.

---

### STEP 2: Setup Database (5 minutes)

**Why**: Create all required tables and permissions.

#### Option A: Supabase SQL Editor (Recommended)

1. Go to: https://dmqsutuniayqtfsaxjuq.supabase.co
2. Click **SQL Editor** (left sidebar)
3. Click **New Query** button
4. Open file: `MASTER_SETUP.sql`
5. **Copy entire file contents**
6. **Paste** in SQL Editor
7. Click **Run** (or press Ctrl+Enter)
8. Wait 10-20 seconds
9. Should see:
   ```
   ✅ DATABASE SETUP COMPLETE!
   ✅ All 3 tables created successfully!
   ✅ RLS enabled on all tables!
   ✅ 8 RLS policies created!
   ```

✅ **Done!** Database is ready.

#### Option B: Direct Database Connection (Advanced)

If SQL Editor doesn't work, use:
```bash
psql "host=db.dmqsutuniayqtfsaxjuq.supabase.co port=5432 dbname=postgres user=postgres" < MASTER_SETUP.sql
```

---

### STEP 3: Verify Database Setup (1 minute)

1. Stay in **SQL Editor**
2. Click **New Query**
3. Run this:

```sql
-- Check tables exist
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('tenants', 'profiles', 'memberships');

-- Should return 3 rows:
-- tenants
-- profiles
-- memberships
```

4. Run this:

```sql
-- Check RLS policies
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename;

-- Should show:
-- tenants: 3 policies
-- profiles: 3 policies
-- memberships: 2 policies
```

✅ **If you see the tables and policies, setup is perfect!**

---

### STEP 4: Rebuild Mobile APK (5 minutes)

```powershell
# Navigate to mobile app
cd c:\Users\rohit\Downloads\ShopOS\apps\mobile

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Build release APK
flutter build apk --release
```

**Build time**: ~3-5 minutes

**APK location**: 
```
build\app\outputs\flutter-apk\app-release.apk
```

✅ **Done!** APK is ready to install.

---

### STEP 5: Install & Test (2 minutes)

#### A. Transfer APK to Android Device
- USB: Copy APK to device
- OR: Use `adb install build\app\outputs\flutter-apk\app-release.apk`
- OR: Email/WhatsApp APK to yourself

#### B. Install APK
- Allow "Install from Unknown Sources"
- Install the APK

#### C. Test Complete Flow

**Test 1: New User Signup + Create Shop**
1. Open ShopOS app
2. Tap **"Sign Up"** tab
3. Enter:
   - Email: `test@example.com`
   - Password: `test123456`
4. Tap **"Sign Up"**
5. ✅ Should see: "Account created successfully!"
6. ✅ Should show: "Create Shop" screen
7. Fill form:
   - Shop Name: `Test Kirana`
   - Phone: `9876543210`
   - Address: `Mumbai`
   - Select: **Retail / Kirana**
8. Tap **"Create Shop"**
9. ✅ Should see: "Shop created successfully!"
10. ✅ Should show: **Home screen** with dashboard

**Test 2: Logout**
1. Tap **account icon** (top-right)
2. Tap **"Logout"**
3. Confirm in dialog
4. ✅ Should return to **Login screen**

**Test 3: Login**
1. Enter same credentials:
   - Email: `test@example.com`
   - Password: `test123456`
2. Tap **"Login"**
3. ✅ Should show: **Home screen** with your shop data

**Test 4: Navigation**
1. Tap each bottom tab:
   - 🏠 Home → Dashboard
   - 📦 Products → Product List
   - 💰 Billing → POS Screen
   - 👥 Customers → Customer List
   - 📄 Invoices → Invoice List
   - ⚙️ Settings → Settings Screen
2. ✅ All should load without errors

---

## 🔍 Troubleshooting

### Issue: "permission denied for table tenants"
**Cause**: RLS policy missing
**Fix**: Run `MASTER_SETUP.sql` again

### Issue: "relation 'public.tenants' does not exist"
**Cause**: Tables not created
**Fix**: Run `MASTER_SETUP.sql` in SQL Editor

### Issue: "Invalid login credentials"
**Cause**: Email confirmation still enabled
**Fix**: Disable email confirmation (Step 1)

### Issue: Build error in Flutter
**Fix**:
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

### Issue: APK won't install
**Cause**: Previous version installed with different signature
**Fix**: Uninstall old version first

### Issue: App crashes on launch
**Cause**: Supabase credentials missing
**Check**: `lib/core/constants/env.dart` has correct URL and key

---

## ✅ Verification Checklist

After setup, you should be able to:

- [ ] Signup with new email
- [ ] See "Account created successfully"
- [ ] See "Create Shop" screen
- [ ] Fill shop details
- [ ] Create shop successfully
- [ ] See Home screen with dashboard
- [ ] Navigate all bottom tabs
- [ ] Logout from account menu
- [ ] Login again with same credentials
- [ ] See your shop data loaded
- [ ] No errors in any flow

---

## 📊 What Was Setup

### Database Tables:
```
┌─────────────┬──────────────────────────┐
│   Table     │        Purpose           │
├─────────────┼──────────────────────────┤
│  tenants    │  Shops/Businesses        │
│  profiles   │  User information        │
│  memberships│  Link users to shops     │
└─────────────┴──────────────────────────┘
```

### User Flow:
```
Signup → Create Shop → Home Screen
           ↑              ↓
        Login ←──── Logout
```

### Features Working:
- ✅ Email/Password Authentication
- ✅ Shop Creation
- ✅ User-Shop Linking
- ✅ Logout (2 ways)
- ✅ Session Management
- ✅ Bottom Navigation
- ✅ All Core Screens

---

## 📁 Important Files

### SQL Files:
- **`MASTER_SETUP.sql`** ⭐ - One script to rule them all

### Documentation:
- **`COMPLETE_SETUP_GUIDE.md`** - This file
- **`USER_FLOW_COMPLETE.md`** - Complete user journey
- **`LOGOUT_FEATURE.md`** - Logout documentation

### Code Files Modified:
- `lib/features/auth/presentation/login_screen.dart` - Email/password login
- `lib/features/onboarding/presentation/create_shop_screen.dart` - Direct DB insert
- `lib/app.dart` - Logout menu added
- `lib/core/constants/env.dart` - Supabase credentials

---

## 🎉 Success!

If you completed all steps and all tests passed, you now have:

✅ **Fully functional ShopOS mobile app**
✅ **Complete authentication system**
✅ **Shop management**
✅ **Zero errors**
✅ **Perfect user flow**

---

## 🚀 Next Steps

Now that setup is complete:

1. **Add Products**: Go to Products tab, add inventory
2. **Add Customers**: Go to Customers tab, add contacts
3. **Create Bills**: Go to Billing tab, create invoices
4. **View Reports**: Go to Reports (from Home quick actions)
5. **Configure Settings**: Go to Settings tab, edit shop profile

---

## 📞 Support

If you encounter any issues:

1. Check error message in app
2. Check Supabase Dashboard → Logs
3. Verify all SQL scripts ran successfully
4. Check relevant documentation file
5. Try rebuilding APK: `flutter clean && flutter build apk --release`

---

## 🎯 Remember

- **Email Confirmation**: MUST be disabled
- **SQL Script**: MUST run completely without errors
- **APK**: MUST rebuild after code changes
- **Clean Install**: Uninstall old version if signature changed

---

**You're all set! Enjoy using ShopOS! 🎊**
