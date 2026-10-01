# Authentication Troubleshooting Guide

## Current Issues & Solutions

### Issue 1: "Invalid login credentials" error
**Symptom**: User signs up successfully, but login fails with "Invalid login credentials"

**Root Cause**: Supabase requires email confirmation by default, but:
- Confirmation emails are not being sent (SMTP not configured)
- User account is created but not confirmed
- Unconfirmed users cannot login

**Solutions** (Choose ONE):

#### ✅ SOLUTION A: Disable Email Confirmation (FASTEST - Recommended for now)
1. Open Supabase Dashboard: https://dmqsutuniayqtfsaxjuq.supabase.co
2. Go to **Authentication** → **Settings**
3. Find **"Enable email confirmations"** under Email Auth
4. **Turn it OFF**
5. Click **Save**

After this:
- Users can signup and login immediately
- No email confirmation needed
- Perfect for development and testing

#### SOLUTION B: Manually Confirm Existing Users
If you have users who already signed up but can't login:

1. Go to Supabase Dashboard → **SQL Editor**
2. Run this query:

```sql
-- Confirm all unconfirmed users
UPDATE auth.users 
SET email_confirmed_at = NOW()
WHERE email_confirmed_at IS NULL;

-- Or confirm specific user
UPDATE auth.users 
SET email_confirmed_at = NOW()
WHERE email = 'specific-email@example.com';
```

#### SOLUTION C: Configure SMTP (For Production Later)
1. Go to **Authentication** → **Settings** → **SMTP Settings**
2. Enable **Custom SMTP**
3. Add Gmail/SendGrid credentials (see SUPABASE_AUTH_SETUP.md)

---

### Issue 2: Not receiving confirmation emails
**Cause**: Supabase uses their default email service which has limitations

**Solution**: Same as Issue 1 - either disable email confirmation or configure custom SMTP

---

### Issue 3: Can't create shop after login
**Possible Causes**:
1. RLS (Row Level Security) policies blocking insert
2. Edge function not deployed
3. Missing database tables

**Debug Steps**:
1. Check browser/app console for errors
2. Verify edge functions are deployed:
   ```bash
   cd supabase
   supabase functions deploy create-tenant
   ```
3. Check RLS policies in Supabase Dashboard → **Authentication** → **Policies**

---

## Updated Login Flow

### Sign Up Flow (After fixing):
```
1. User opens app
2. Clicks "Sign Up" tab
3. Enters email + password
4. Clicks "Sign Up"
5. ✅ Account created + auto-logged in
6. → Redirects to "Create Shop" screen
7. User fills shop details
8. Clicks "Create Shop"
9. ✅ Shop created
10. → Redirects to Home screen
```

### Login Flow:
```
1. User opens app (already has account)
2. "Login" tab is selected by default
3. Enters email + password
4. Clicks "Login"
5. ✅ Logged in
6. → Redirects to Home screen (if shop exists)
   OR → Redirects to "Create Shop" (if no shop)
```

---

## Testing Instructions

### After Disabling Email Confirmation:

1. **Test Signup**:
   ```
   Email: test@example.com
   Password: test123456
   Expected: ✅ Account created → Create Shop screen
   ```

2. **Test Login**:
   ```
   Email: test@example.com
   Password: test123456
   Expected: ✅ Logged in → Home or Create Shop screen
   ```

3. **Test Invalid Login**:
   ```
   Email: wrong@example.com
   Password: wrongpass
   Expected: ❌ Error: "Invalid email or password"
   ```

---

## Quick Verification Checklist

- [ ] Disable email confirmation in Supabase Dashboard
- [ ] Test signup with new email
- [ ] Verify account created in Dashboard → Authentication → Users
- [ ] Test login with same credentials
- [ ] Verify redirect to Create Shop screen
- [ ] Create shop and verify redirect to Home

---

## Code Changes Made

### login_screen.dart
✅ Changed from OTP to Email/Password authentication
✅ Added Login/Signup toggle
✅ Added better error messages
✅ Added email confirmation handling
✅ Added auth state listener for magic links

### env.dart
✅ Updated Supabase URL: https://dmqsutuniayqtfsaxjuq.supabase.co
✅ Updated Anon Key: sb_publishable_Na2Ql0HkKp9enLLBWYTOsQ_sJx9GnIr

---

## Next Steps

1. ✅ **First**: Disable email confirmation in Supabase Dashboard
2. ✅ **Then**: Rebuild APK: `flutter build apk --release`
3. ✅ **Test**: Install APK and test signup → create shop → login flow
4. ✅ **Later**: Configure custom SMTP for production use

---

## Support

If issues persist after disabling email confirmation:
1. Check Supabase Dashboard → **Logs** for errors
2. Check RLS policies are configured correctly
3. Verify edge functions are deployed
4. Check that auth.users table has the new user
