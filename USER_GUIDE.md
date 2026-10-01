# ShopOS - User Guide

Complete guide for shop owners to use ShopOS mobile app.

---

## Getting Started

### Download & Install

1. Open Play Store on your Android phone
2. Search for "ShopOS"
3. Tap "Install"
4. Wait for download to complete (app size: ~40 MB)

### First Time Setup

#### Step 1: Sign Up

1. Open ShopOS app
2. Tap "Get Started"
3. Enter your mobile number (example: `9876543210`)
4. Tap "Send OTP"
5. Enter the 6-digit OTP you receive via SMS
6. Tap "Verify"

#### Step 2: Create Your Shop

1. Enter shop details:
   - **Shop Name**: Your shop name (example: "Raj Kirana Store")
   - **Shop Type**: Choose from dropdown:
     - Retail / Kirana
     - Pharmacy
     - Salon
     - Restaurant
     - Boutique
     - Repair Shop
   - **Phone Number**: Your contact number (optional)
   - **Address**: Full shop address (optional)
   - **GSTIN**: GST number if registered (optional)

2. Tap "Next"

#### Step 3: Choose Template

Select the template that matches your business:

- **Retail / Kirana**: Products, customers, invoices, suppliers
- **Pharmacy**: Medicines, batches, expiry tracking, prescriptions
- **Salon**: Services, staff, appointments, packages
- **Restaurant**: Menu items, tables, orders, KOT
- **Boutique**: Garments, sizes, colors, measurements
- **Repair Shop**: Devices, job cards, spare parts

Tap "Get Started" to create your shop.

#### Step 4: Quick Tour (Optional)

- Skip: Tap "Skip" to start using immediately
- Take Tour: Tap "Show Me Around" for guided walkthrough

---

## Managing Products

### Add New Product

1. Tap "Products" from home screen
2. Tap the "+" button (bottom right)
3. Fill product details:
   - **Product Name**: Name of the item
   - **SKU/Barcode**: Scan or type manually
   - **Category**: Product category
   - **Selling Price**: Price you sell at
   - **Cost Price**: Price you bought at (optional)
   - **Stock Quantity**: Current stock count
   - **Minimum Stock**: Alert level
   - **Unit**: pcs, kg, ltr, box, dozen
   - **GST Rate**: 0%, 5%, 12%, 18%, or 28%
   - **HSN Code**: For GST filing (optional)
   - **Image**: Take photo or upload
4. Tap "Save"

**Tip**: Use barcode scanner for faster entry!

### Scan Barcode

1. In add product screen, tap barcode icon next to SKU field
2. Point camera at barcode
3. App automatically fills SKU
4. Continue filling other details

### Edit Product

1. Go to Products
2. Tap on product card
3. Edit any field
4. Tap "Save"

### Delete Product

1. Go to Products
2. Long press on product card
3. Tap "Delete"
4. Confirm deletion

### Low Stock Alerts

When product stock reaches minimum level:
- Red badge appears on product
- WhatsApp notification sent (if enabled)
- Appears in "Low Stock" report

---

## Billing (POS)

### Create Invoice

1. Tap "Billing" from home screen
2. Tap "New Invoice"
3. Add items:
   - **Option 1**: Scan barcode
   - **Option 2**: Search by name
   - **Option 3**: Browse categories
   - **Option 4**: Recent items list

4. For each item:
   - Adjust quantity using +/- buttons
   - Add discount (per item or bill level)
   - GST automatically calculated

5. Add customer (optional):
   - Tap "Add Customer"
   - Select from list or add new
   - Required for credit sales

6. Choose payment mode:
   - Cash
   - UPI
   - Card
   - Credit (adds to customer ledger)

7. Tap "Generate Invoice"

### Print Invoice

After generating invoice:

**Option 1: Thermal Printer** (58mm/80mm)
1. Connect Bluetooth printer (Settings → Printer)
2. Tap "Print"
3. Invoice prints automatically

**Option 2: Share PDF**
1. Tap "Share"
2. Choose WhatsApp, Email, or Save to Phone
3. PDF attached automatically

**Option 3: Show on Screen**
1. Tap "View"
2. Show to customer
3. Customer can screenshot

### UPI Payment

1. After generating invoice, tap "UPI QR"
2. Customer scans with PhonePe/GPay/Paytm
3. After payment, mark as paid manually
4. Or wait for auto-verification (if configured)

### Credit Sales

1. During billing, choose "Credit" payment mode
2. Select customer (required)
3. Amount added to customer's outstanding balance
4. Customer sees this in their ledger

---

## Managing Customers

### Add Customer

1. Tap "Customers" from home
2. Tap "+" button
3. Fill details:
   - Name (required)
   - Phone number
   - Email
   - Address
   - GSTIN (for GST customers)
   - Credit limit
4. Tap "Save"

### Quick Add During Billing

1. In billing screen, tap "Add Customer"
2. Tap "Quick Add"
3. Enter name and phone only
4. Tap "Save"
5. Complete details later

### View Customer Ledger

1. Go to Customers
2. Tap on customer name
3. See:
   - Outstanding balance
   - Credit limit
   - Transaction history
   - Invoices (paid & unpaid)

### Record Payment

1. Open customer ledger
2. Tap "Record Payment"
3. Enter amount received
4. Choose payment mode
5. Tap "Save"
6. Outstanding reduces automatically

### Send Payment Reminder

1. Open customer ledger
2. Tap "Remind" button
3. WhatsApp message sent automatically
4. Shows outstanding amount and payment link

---

## Reports

### Daily Sales Report

1. Tap "Reports" from home
2. Select "Daily Sales"
3. Choose date
4. See:
   - Total sales
   - Number of invoices
   - Cash vs UPI vs Card
   - Top selling items
   - Tax collected

### Weekly/Monthly Sales

1. Select "Weekly" or "Monthly" tab
2. Choose date range
3. View trend chart
4. Export to CSV or PDF

### Stock Report

1. Go to Reports → Stock
2. See:
   - Current stock value
   - Low stock items
   - Out of stock items
   - Dead stock (not sold in 90 days)

### Customer Report

1. Go to Reports → Customers
2. See:
   - Top customers by revenue
   - Outstanding aging (0-30, 30-60, 60+ days)
   - Credit utilization

### Export Report

1. Open any report
2. Tap "Export" button
3. Choose format:
   - CSV (Excel compatible)
   - PDF (printable)
4. Share via WhatsApp or Email

---

## Staff Management

### Add Staff Member

1. Go to Settings → Staff
2. Tap "Add Staff"
3. Fill details:
   - Name
   - Phone number
   - Role: Owner, Manager, Cashier, Viewer
4. Tap "Send Invite"
5. Staff receives WhatsApp link to join

### Roles & Permissions

| Role | Can Do |
|------|--------|
| **Owner** | Everything (full access) |
| **Manager** | Billing, reports, inventory, customers (no settings) |
| **Cashier** | Billing only (read inventory) |
| **Viewer** | View reports only |

### Remove Staff

1. Go to Settings → Staff
2. Tap on staff name
3. Tap "Remove Access"
4. Confirm removal

---

## Subscription Plans

### Free Plan (14-day trial)
- 1 shop
- 1 user
- 50 products
- 100 invoices/month

### Basic Plan (₹149/month)
- 1 shop
- 3 users
- 1000 products
- Unlimited invoices
- Email support

### Standard Plan (₹299/month)
- Everything in Basic
- 10 users
- WhatsApp notifications
- Loyalty program
- Advanced reports
- Low stock alerts

### Pro Plan (₹599/month)
- Everything in Standard
- 3 shops
- API access
- Custom domain
- Priority support

### How to Upgrade

1. Go to Settings → Subscription
2. Tap "Upgrade Now"
3. Choose plan
4. Pay via UPI/Card/Net Banking
5. Instant activation

---

## Settings

### Shop Profile

1. Go to Settings → Shop Profile
2. Edit:
   - Shop name
   - Logo (tap to upload)
   - Address
   - Contact details
   - GST details
3. Tap "Save"

### Tax Settings

1. Go to Settings → Tax Settings
2. Choose:
   - GST Enabled: Yes/No
   - Default GST rate
   - Include tax in price: Yes/No
3. Tap "Save"

### Printer Setup

1. Go to Settings → Printer
2. Tap "Connect Printer"
3. Turn on Bluetooth printer
4. Select from list
5. Test print

**Supported Printers**:
- 58mm thermal printers
- 80mm thermal printers
- Any ESC/POS compatible printer

### Change Language

1. Go to Settings → Language
2. Choose from:
   - English
   - हिन्दी (Hindi)
   - मराठी (Marathi)
   - தமிழ் (Tamil)
   - తెలుగు (Telugu)
3. App restarts with new language

### Backup Data

1. Go to Settings → Backup
2. Tap "Backup Now"
3. Data uploaded to cloud
4. Shows last backup time

**Auto Backup**: Every night at 2 AM (if internet available)

### Restore Data

1. Go to Settings → Backup
2. Tap "Restore"
3. Choose backup date
4. Confirm restore
5. App restarts with restored data

**⚠️ Warning**: Current data will be replaced!

---

## Offline Mode

ShopOS works 100% offline!

### What Works Offline:
- ✅ Create invoices
- ✅ Add products
- ✅ Manage customers
- ✅ View reports
- ✅ Print receipts (Bluetooth printer)

### What Needs Internet:
- ❌ WhatsApp notifications
- ❌ Online payments
- ❌ Data sync across devices
- ❌ Subscription renewal

### Sync Status

Check top-right corner of app:
- 🟢 **Green**: All synced
- 🟡 **Yellow**: Syncing...
- 🔴 **Red**: Offline (X pending)
- ⚫ **Gray**: No internet

Tap icon to see sync details.

---

## Troubleshooting

### Invoice Not Printing

1. Check printer is on
2. Check Bluetooth connected
3. Check printer has paper
4. Try test print from Settings
5. Reconnect printer

### Barcode Not Scanning

1. Check camera permission granted
2. Clean camera lens
3. Ensure good lighting
4. Hold barcode 10-15 cm from camera
5. Try typing manually

### App Crashes

1. Close and restart app
2. Check phone storage (need 100MB free)
3. Update app from Play Store
4. Clear app cache (Settings → Apps → ShopOS → Clear Cache)
5. Reinstall app (data safe in cloud)

### Data Not Syncing

1. Check internet connection
2. Check sync status (top-right icon)
3. Try manual sync (Settings → Data → Sync Now)
4. Wait 30 seconds, auto-sync happens
5. Check subscription is active

### OTP Not Received

1. Check mobile number correct
2. Check SMS inbox (not spam)
3. Wait 60 seconds, try resend
4. Check phone has network signal
5. Contact support via WhatsApp

---

## Tips & Best Practices

### Daily Routine

**Morning** (9 AM):
1. Open app
2. Check sync status (should be green)
3. Review yesterday's sales (Reports → Daily)
4. Check low stock items

**During Day**:
- Use barcode scanner for fast billing
- Add customers for credit sales
- Check battery level (keep charged)

**Evening** (9 PM):
1. Review day's sales
2. Collect customer payments
3. Check cash in hand vs app total
4. Backup data (Settings → Backup)

### Inventory Management

- Update stock after every purchase
- Set minimum stock levels
- Review dead stock monthly
- Use categories for easier search

### Customer Management

- Add customers for repeat buyers
- Offer credit to trusted customers
- Set credit limits
- Send reminders on time
- Reward top customers

### Performance Tips

- Delete old data (2+ years) to keep app fast
- Take smaller product images
- Clear app cache monthly
- Update app when prompted

---

## Support

### Help Center
- In-app: Settings → Help
- Website: https://docs.shopos.app

### Contact Support

**WhatsApp**: +91-XXXXXXXXXX (preferred)  
**Email**: support@shopos.app  
**Phone**: Available for Pro plan only

**Response Time**:
- WhatsApp: Within 2 hours (9 AM - 9 PM)
- Email: Within 24 hours
- Phone: Immediate

### Community

Join our shop owner community:
- WhatsApp Group: [Link]
- Telegram Channel: [Link]
- Facebook Group: [Link]

---

## Keyboard Shortcuts (Bluetooth Keyboard)

If using Bluetooth keyboard with tablet:

- `Ctrl + N`: New invoice
- `Ctrl + P`: Print last invoice
- `Ctrl + F`: Search products
- `Ctrl + R`: Open reports
- `F2`: Scan barcode
- `Esc`: Cancel current action

---

*Last Updated: September 29, 2026*  
*App Version: 1.0.0*
