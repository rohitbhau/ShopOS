# ShopOS Mobile App - Complete Setup Instructions

## Current Status
✅ **Authentication Working** - Signup successful, user created with ID: `fe5c21b8-ea11-4959-8f00-5f38f05785cb`
❌ **Database Tables Missing** - Need to create `profiles`, `tenants`, `memberships` tables

---

## Step 1: Setup Supabase Database Tables

### Option A: Using Supabase SQL Editor (Recommended)

1. Go to your Supabase Dashboard: https://dmqsutuniayqtfsaxjuq.supabase.co
2. Click **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy and paste the entire contents of `SUPABASE_SETUP.sql` file
5. Click **Run** (or press Ctrl+Enter)
6. Wait for "Success. No rows returned" message

### Option B: Using Supabase CLI (If you have it installed)

```bash
cd packages/supabase
supabase db push
```

---

## Step 2: Verify Database Setup

After running the SQL, verify in Supabase Dashboard:

1. Go to **Table Editor**
2. You should see these tables:
   - ✅ `tenants` - Stores shop/business information
   - ✅ `profiles` - User profile data
   - ✅ `memberships` - Links users to their shops with roles

3. Click on `profiles` table
4. You should see your user: `fe5c21b8-ea11-4959-8f00-5f38f05785cb`

---

## Step 3: Rebuild Mobile APK

```powershell
cd c:\Users\rohit\Downloads\ShopOS\apps\mobile
flutter build apk --release
```

APK will be at: `build\app\outputs\flutter-apk\app-release.apk`

---

## Step 4: Test Complete Flow

### A. First Time Signup & Shop Creation

1. **Install APK** on your Android device
2. **Open ShopOS app**
3. Click **"Sign Up"** tab
4. Enter:
   - Email: `newuser@example.com`
   - Password: `test123456`
5. Click **"Sign Up"**
6. ✅ Should show: "Account created successfully!"
7. ✅ Should redirect to "Create Shop" screen
8. Fill shop details:
   - Shop Name: `My Kirana Store`
   - Phone: `9876543210`
   - Address: `123 Main Street, Mumbai`
   - GSTIN: (optional)
   - Select shop type: **Retail / Kirana**
9. Click **"Create Shop"**
10. ✅ Should show: "Shop created successfully!"
11. ✅ Should redirect to Home screen

### B. Login with Existing Account

1. **Open ShopOS app** (or logout and reopen)
2. **"Login"** tab should be selected
3. Enter:
   - Email: `rkumbhare1234@gmail.com` (your existing account)
   - Password: (your password)
4. Click **"Login"**
5. If shop already exists: ✅ Go to Home
6. If no shop: ✅ Go to "Create Shop" screen

---

## Step 5: Verify in Supabase Dashboard

After creating a shop, check in Supabase:

### Check Tenants Table
```sql
SELECT * FROM tenants;
```
Should show your shop with name, phone, address, etc.

### Check Memberships Table
```sql
SELECT 
    m.id,
    t.name as shop_name,
    p.name as user_name,
    m.role,
    m.is_active
FROM memberships m
JOIN tenants t ON m.tenant_id = t.id
JOIN profiles p ON m.user_id = p.id;
```
Should show link between user and their shop with role = 'owner'

---

## What Was Fixed

### 1. Login Screen (`login_screen.dart`)
✅ Changed from OTP to Email/Password authentication
✅ Added Login/Signup toggle
✅ Better error messages for common issues:
   - Invalid credentials
   - Email not confirmed
   - User already exists
✅ Auth state listener for magic link support

### 2. Create Shop Screen (`create_shop_screen.dart`)
✅ Removed dependency on edge functions
✅ Direct database insert for tenant creation
✅ Creates profile if not exists
✅ Creates membership linking user to shop
✅ Better error handling with PostgrestException

### 3. Environment Config (`env.dart`)
✅ Updated Supabase URL
✅ Updated Supabase Anon Key

### 4. Database Setup (`SUPABASE_SETUP.sql`)
✅ Creates all required tables
✅ Sets up RLS policies for security
✅ Creates helper functions (auth.tenant_id, auth.user_role)
✅ Inserts initial profile for existing user

---

## Troubleshooting

### Issue: "404 Not Found" on profiles or tenants
**Solution**: Run `SUPABASE_SETUP.sql` in SQL Editor

### Issue: "Invalid login credentials" after signup
**Solution**: Disable email confirmation in Supabase Dashboard (see AUTH_TROUBLESHOOTING.md)

### Issue: Can't create shop - "permission denied"
**Solution**: Check RLS policies are created correctly. Verify user is authenticated.

### Issue: Shop created but can't see home screen
**Solution**: Check that memberships table has entry linking user to tenant

---

## Database Schema Overview

```
auth.users (Supabase managed)
    ↓ (id)
profiles (our table)
    ↑ (user_id)
    ↓
memberships ←→ tenants
    ↓              ↓
  (role)      (shop data)
```

**Flow**:
1. User signs up → `auth.users` entry created
2. Login successful → Create `profiles` entry
3. Create shop → Create `tenants` entry
4. Link user to shop → Create `memberships` entry with role='owner'
5. Future logins → Check `memberships` to find user's shop(s)

---

## Next Steps After Setup

1. ✅ Run `SUPABASE_SETUP.sql`
2. ✅ Rebuild APK
3. ✅ Test signup → create shop → login flow
4. 🎯 Start using the app!
5. 🚀 Add products, customers, create bills

---

## Support Files Created

- `SUPABASE_SETUP.sql` - Complete database setup script
- `SUPABASE_AUTH_SETUP.md` - Email confirmation configuration
- `AUTH_TROUBLESHOOTING.md` - Common auth issues and solutions
- `SETUP_INSTRUCTIONS.md` - This file

---

## Ready to Go! 🚀

Your user is created, authentication is working, code is updated. Just need to:
1. Run the SQL script
2. Rebuild APK
3. Test the flow

Everything should work smoothly after that!
