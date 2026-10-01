# Quick Fix for Build Errors

## Issue
The code uses `.is_()` and `.eq('deleted_at', null)` which don't work with current Supabase version.

## Solution
Remove the deleted_at filters since we're not using soft deletes.

## Files to Fix

Run these commands:

```powershell
cd c:\Users\rohit\Downloads\ShopOS\apps\mobile

# Remove deleted_at filters from all files
(Get-Content lib/features/products/presentation/product_list_screen.dart) -replace "\.eq\('deleted_at', null\)", "" | Set-Content lib/features/products/presentation/product_list_screen.dart

(Get-Content lib/features/billing/presentation/billing_screen.dart) -replace "\.eq\('deleted_at', null\)", "" | Set-Content lib/features/billing/presentation/billing_screen.dart

(Get-Content lib/features/reports/presentation/reports_screen.dart) -replace "\.eq\('deleted_at', null\);", ";" | Set-Content lib/features/reports/presentation/reports_screen.dart

(Get-Content lib/features/customers/presentation/customer_list_screen.dart) -replace "\.eq\('deleted_at', null\)", "" | Set-Content lib/features/customers/presentation/customer_list_screen.dart

(Get-Content lib/features/customers/presentation/customer_detail_screen.dart) -replace "\.eq\('deleted_at', null\)", "" | Set-Content lib/features/customers/presentation/customer_detail_screen.dart

(Get-Content lib/features/invoices/presentation/invoice_list_screen.dart) -replace "\.eq\('deleted_at', null\)", "" | Set-Content lib/features/invoices/presentation/invoice_list_screen.dart

# Then build
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`
