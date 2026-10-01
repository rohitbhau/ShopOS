# Supabase Authentication Setup Guide

## Issue: Users can't login after signup

### Root Cause
Supabase requires email confirmation by default, but confirmation emails are not being sent.

## Solution Options

### Option 1: Disable Email Confirmation (Recommended for Development)

1. Go to your Supabase Dashboard: https://dmqsutuniayqtfsaxjuq.supabase.co
2. Navigate to **Authentication** → **Settings**
3. Scroll to **"Email Auth"** section
4. Find **"Enable email confirmations"** toggle
5. **Turn it OFF** (disable)
6. Click **Save**

**Result**: Users can signup and login immediately without email confirmation.

---

### Option 2: Configure Email Provider (For Production)

If you want to keep email confirmation enabled, you need to configure an email provider:

#### Using Custom SMTP (Gmail, SendGrid, Mailgun, etc.)

1. Go to **Authentication** → **Settings** → **SMTP Settings**
2. Enable **"Enable Custom SMTP"**
3. Configure your email provider:

**Gmail Example:**
```
Host: smtp.gmail.com
Port: 587
Username: your-email@gmail.com
Password: your-app-password (not regular password!)
Sender Email: your-email@gmail.com
Sender Name: ShopOS
```

**Note for Gmail**: 
- You need to create an "App Password" in Google Account settings
- Go to: Google Account → Security → 2-Step Verification → App passwords
- Generate a password for "Mail" / "Other device"

#### Using SendGrid
```
Host: smtp.sendgrid.net
Port: 587
Username: apikey
Password: <your-sendgrid-api-key>
Sender Email: noreply@yourdomain.com
Sender Name: ShopOS
```

---

## Testing After Configuration

### If Email Confirmation is DISABLED:
1. Open ShopOS mobile app
2. Click **"Sign Up"** tab
3. Enter email: `test@example.com`
4. Enter password: `password123`
5. Click **"Sign Up"**
6. Should see: "Account created successfully!"
7. Automatically logged in → proceeds to "Create Shop" screen

### If Email Confirmation is ENABLED:
1. Follow steps 1-5 above
2. Should see: "Please check your email to confirm your account"
3. Check email inbox for confirmation link
4. Click the link in email
5. Return to app and click **"Login"** tab
6. Enter same email and password
7. Click **"Login"**
8. Should login successfully → proceeds to home or "Create Shop"

---

## Current Configuration

**Supabase Project**: https://dmqsutuniayqtfsaxjuq.supabase.co
**Anon Key**: sb_publishable_Na2Ql0HkKp9enLLBWYTOsQ_sJx9GnIr

---

## Troubleshooting

### "Invalid login credentials" error
- **Cause**: Account exists but email is not confirmed
- **Solution**: Disable email confirmation OR configure SMTP

### "User already registered" error
- **Cause**: Trying to signup with an existing email
- **Solution**: Use "Login" tab instead of "Sign Up"

### Email not received
- **Cause**: SMTP not configured or emails going to spam
- **Solution**: 
  1. Check spam folder
  2. Configure custom SMTP with a real email provider
  3. OR disable email confirmation

### Can't create shop after login
- **Cause**: Authentication works but database permissions issue
- **Solution**: Check RLS (Row Level Security) policies in Supabase

---

## Quick Fix Command

To manually confirm a user in Supabase SQL Editor:

```sql
-- Replace with actual user email
UPDATE auth.users 
SET email_confirmed_at = NOW()
WHERE email = 'your-email@example.com';
```

This manually confirms the email without needing the confirmation link.
