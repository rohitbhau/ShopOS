# ShopOS - Quick Start Guide (5 Minutes)

Complete flow to test the app end-to-end.

## Prerequisites Done ✅
- Flutter project structure ✅
- Supabase migrations (8 files) ✅
- Edge functions (2 complete, 7 scaffolded) ✅
- Complete Auth flow ✅
- Complete Onboarding ✅
- Complete Product Management ✅
- Complete Billing/POS ✅

## What Works Right Now

### ✅ Fully Functional
1. **Phone OTP Login** - Real Supabase auth
2. **Create Shop** - With templates
3. **Product Management** - Add, edit, delete products
4. **Billing/POS** - Add to cart, generate invoice, update stock
5. **Dashboard** - Shows today's sales summary
6. **Offline-Ready** - All data saves to Supabase

### 🔄 Next to Build
- Sync engine integration (for true offline)
- Reports screen
- Customer management
- Staff management
- Settings

---

## Setup Steps

### 1. Supabase Setup (2 minutes)

```bash
# Go to supabase.com and create project
# Note: Project URL and anon key

cd packages/supabase

# Login
supabase login

# Link project
supabase link --project-ref YOUR_PROJECT_REF

# Run all migrations
supabase db push

# Deploy edge functions
supabase functions deploy auth-set-tenant-claim
supabase functions deploy create-tenant
supabase functions deploy seed-template
```

### 2. Flutter Setup (2 minutes)

```bash
cd apps/mobile

# Create .env file
cat > .env << EOF
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
EOF

# Install dependencies
flutter pub get

# Run app
flutter run
```

---

## Testing Flow (Complete End-to-End)

### Test 1: Signup → Onboarding
1. Open app
2. Enter phone: `9876543210`
3. Click "Send OTP"
4. Check Supabase Dashboard → Authentication → Users
5. Copy OTP from user's "Phone Confirmed At" field
6. Enter OTP → Verify
7. Should navigate to "Create Shop" screen
8. Fill shop details:
   - Name: "Test Kirana Store"
   - Type: Select "Retail"
   - Phone: "9876543210"
9. Click "Create Shop"
10. Should navigate to Home screen

**Expected**: Shop created, entities seeded (product, customer, invoice)

### Test 2: Add Products
1. Tap "Products" from bottom nav
2. Tap "+" button
3. Fill product:
   - Name: "Tata Salt 1kg"
   - Price: 50
   - Stock: 100
   - Min Stock: 10
   - GST: 18%
4. Tap "Add Product"
5. Should see product in list

**Repeat** for 3-4 more products:
- "Maggi 2-Minute" - ₹12, Stock: 200
- "Amul Milk 500ml" - ₹28, Stock: 50
- "Parle-G Biscuits" - ₹10, Stock: 150

### Test 3: Create Invoice (Billing)
1. Tap "Billing" from bottom nav
2. Search "Tata Salt"
3. Tap on product → adds to cart
4. Search "Maggi"
5. Tap on product → adds to cart
6. Adjust quantity using +/- buttons:
   - Tata Salt: 2
   - Maggi: 5
7. Payment mode: Select "Cash"
8. Tap "Generate Invoice"
9. Should show success dialog with invoice number
10. Tap "Done"

**Expected**:
- Invoice saved to database
- Stock updated (Tata Salt: 100 → 98, Maggi: 200 → 195)
- Cart cleared

### Test 4: Verify Data in Supabase
1. Go to Supabase Dashboard → Table Editor
2. Check `tenants` table - 1 row
3. Check `profiles` table - 1 row
4. Check `memberships` table - 1 row (role: owner)
5. Check `apps` table - 1 row (name: "Main App")
6. Check `entities` table - 3 rows (product, customer, invoice)
7. Check `records` table:
   - 4 product records (Tata Salt, Maggi, Milk, Parle-G)
   - 1 invoice record with items array
   - Stock values updated

---

## Verify Specific Features

### Phone OTP
```sql
-- Check user created
SELECT id, phone, created_at FROM auth.users;

-- Check profile
SELECT * FROM profiles WHERE phone = '+919876543210';

-- Check membership
SELECT m.*, t.name as shop_name 
FROM memberships m 
JOIN tenants t ON m.tenant_id = t.id;
```

### Tenant Isolation (RLS Test)
```sql
-- This should work (returns shop data)
SELECT * FROM tenants WHERE id = auth.tenant_id();

-- This should return empty (RLS blocks other tenants)
SELECT * FROM tenants WHERE id != auth.tenant_id();
```

### Entity Schema
```sql
-- Check entities created
SELECT name, label, is_system FROM entities ORDER BY name;

-- Check product schema
SELECT schema FROM entities WHERE name = 'product';
```

### Invoice Data
```sql
-- Check invoice
SELECT 
  id,
  data->>'invoice_number' as invoice_num,
  data->>'total' as total,
  data->>'payment_mode' as payment,
  created_at
FROM records
WHERE entity_id = (SELECT id FROM entities WHERE name = 'invoice')
ORDER BY created_at DESC
LIMIT 1;

-- Check invoice items
SELECT 
  data->'items' as items
FROM records
WHERE entity_id = (SELECT id FROM entities WHERE name = 'invoice')
LIMIT 1;
```

### Stock Update Verification
```sql
-- Check product stock
SELECT 
  data->>'name' as product_name,
  data->>'stock' as current_stock,
  updated_at
FROM records
WHERE entity_id = (SELECT id FROM entities WHERE name = 'product')
ORDER BY updated_at DESC;
```

---

## Troubleshooting

### OTP Not Received
**Solution**: In Supabase Dashboard → Authentication → Settings → Enable "Disable email confirmation" for testing. Or check "Users" table for OTP.

### "Unauthorized" Error
**Solution**: 
1. Check JWT contains tenant_id:
```sql
SELECT auth.tenant_id(); -- Should return UUID
```
2. Re-login to refresh JWT

### Products Not Loading
**Solution**:
1. Check entities table has "product" entity
2. Check RLS policies enabled:
```sql
SELECT tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE schemaname = 'public';
```

### Invoice Generation Fails
**Solution**:
1. Check invoice entity exists
2. Check user has "owner" or "cashier" role
3. Check RLS policy allows INSERT on records

---

## Performance Checks

### Page Load Times
- Login screen: < 1s
- Product list (100 products): < 2s
- Billing screen: < 1s
- Invoice generation: < 3s

### Database Queries
All queries should use indexes:
```sql
-- Check slow queries
SELECT * FROM pg_stat_statements 
WHERE mean_exec_time > 100 
ORDER BY mean_exec_time DESC;
```

---

## Next Steps After Testing

### Phase 2: Offline Sync
1. Integrate Drift local database
2. Connect sync engine
3. Test offline invoice generation
4. Test online sync after 30s

### Phase 3: Reports
1. Daily sales summary
2. Top products chart
3. Stock valuation
4. Export to CSV/PDF

### Phase 4: Advanced Features
1. Customer ledger
2. Credit sales
3. Payment reminders
4. Staff management

---

## Quick Demo Script (2 minutes)

```
1. [0:00-0:20] Login with OTP
   → Show OTP verification working

2. [0:20-0:40] Create shop "Demo Kirana"
   → Template seeded automatically

3. [0:40-1:00] Add 2 products quickly
   → Tata Salt ₹50, Maggi ₹12

4. [1:00-1:40] Create invoice
   → Search, add to cart, adjust quantity, generate
   → Show invoice number and total

5. [1:40-2:00] Verify in product list
   → Stock reduced automatically
   → Low stock alert visible (if below min)
```

---

## Known Working Features Summary

| Feature | Status | Notes |
|---------|--------|-------|
| Phone OTP Login | ✅ Working | Real Supabase auth |
| Create Shop | ✅ Working | With template seeding |
| Add Product | ✅ Working | Full validation |
| Edit Product | ✅ Working | Updates in real-time |
| Delete Product | ✅ Working | Soft delete |
| Product Search | ✅ Working | By name or SKU |
| Stock Filters | ✅ Working | All, Low Stock, Out of Stock |
| Add to Cart | ✅ Working | With quantity controls |
| Generate Invoice | ✅ Working | Saves + updates stock |
| Payment Modes | ✅ Working | Cash, UPI, Card |
| GST Calculation | ✅ Working | Per-item rates |
| Dashboard | ✅ Working | Shows summary |
| Bottom Navigation | ✅ Working | 4 tabs |
| Supabase RLS | ✅ Working | Tenant isolation |
| Multi-tenant | ✅ Working | JWT with tenant_id |

---

*Last Updated: September 29, 2026*  
*Build Status: Core Flow Complete*  
*Next: Sync Engine Integration*
