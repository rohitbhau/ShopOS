# Complete Remaining 5% - Action Plan

**Current Status**: 95% Complete  
**Remaining**: 5% (2-3 hours of work)  
**Goal**: 100% Production-Ready

---

## Task List

### Task 1: Generate Drift Database Code (5 minutes) ⚡

**Why**: Drift needs generated code to work at runtime  
**Priority**: CRITICAL - App won't compile without this

```bash
cd apps/mobile
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

**Expected Output**:
- `lib/core/database/app_database.g.dart` created
- No errors in console

**Verify**:
```bash
ls lib/core/database/app_database.g.dart
# Should exist
```

---

### Task 2: Wire Barcode Scanner to Billing (1 hour) 🔧

**File to Edit**: `apps/mobile/lib/features/billing/presentation/billing_screen.dart`

**Changes Needed**:

1. **Import scanner**:
```dart
import 'barcode_scanner_screen.dart';
```

2. **Update scanner button** (around line 350):
```dart
// Find the IconButton with qr_code_scanner icon
IconButton(
  icon: const Icon(Icons.qr_code_scanner),
  onPressed: () async {
    // Replace existing onPressed with:
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(),
      ),
    );
    
    if (code != null && code.isNotEmpty) {
      // Set search text to scanned code
      _searchController.text = code;
      // Trigger search
      _searchProducts(code);
      // Auto-add if single result
      if (_filteredProducts.length == 1) {
        _addToCart(_filteredProducts.first);
        _searchController.clear();
        _searchProducts('');
        FocusScope.of(context).unfocus();
      }
    }
  },
),
```

**Test**:
1. Go to Billing screen
2. Tap barcode button
3. Point at barcode
4. Product should auto-add to cart

---

### Task 3: Integrate PDF Export (1 hour) 📄

**File to Edit**: `apps/mobile/lib/features/invoices/presentation/invoice_detail_screen.dart`

**Changes Needed**:

1. **Import services**:
```dart
import '../../../core/services/pdf_service.dart';
import '../../../core/services/whatsapp_service.dart';
import 'dart:io';
```

2. **Add PDF generation method** (add to state class):
```dart
Future<void> _generatePdf() async {
  if (_invoiceData == null) return;

  setState(() => _isLoading = true);

  try {
    final supabase = Supabase.instance.client;
    
    // Get shop details
    final membership = await supabase
        .from('memberships')
        .select('tenant_id')
        .eq('user_id', supabase.auth.currentUser!.id)
        .single();
    
    final tenant = await supabase
        .from('tenants')
        .select()
        .eq('id', membership['tenant_id'])
        .single();
    
    final data = _invoiceData!['data'] as Map<String, dynamic>;
    final items = (data['items'] as List).map((item) => 
      PdfService.InvoiceItem(
        name: item['name'],
        quantity: item['quantity'],
        price: (item['price'] as num).toDouble(),
        gstRate: (item['gst_rate'] as num).toDouble(),
        total: (item['total'] as num).toDouble(),
      )
    ).toList();
    
    // Generate PDF
    final pdf = await PdfService.generateInvoicePdf(
      shopName: tenant['name'] ?? 'Shop',
      shopAddress: tenant['address'] ?? '',
      shopPhone: tenant['phone'] ?? '',
      shopGstin: tenant['gstin'] ?? '',
      invoiceNumber: data['invoice_number'],
      invoiceDate: DateTime.parse(data['invoice_date']),
      customerName: data['customer_name'],
      customerPhone: data['customer_phone'],
      customerAddress: data['customer_address'],
      items: items,
      subtotal: (data['subtotal'] as num).toDouble(),
      taxAmount: (data['tax_amount'] as num).toDouble(),
      total: (data['total'] as num).toDouble(),
      paymentMode: data['payment_mode'],
      paymentStatus: data['payment_status'],
    );
    
    // Share PDF
    await PdfService.sharePdf(pdf);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generated and ready to share'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF error: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

3. **Add Share button** (in the actions of AppBar or as FAB):
```dart
// In AppBar actions:
IconButton(
  icon: const Icon(Icons.share),
  onPressed: _generatePdf,
),

// Or as Floating Action Button:
floatingActionButton: FloatingActionButton.extended(
  onPressed: _generatePdf,
  icon: const Icon(Icons.picture_as_pdf),
  label: const Text('Share PDF'),
),
```

**Test**:
1. Open invoice detail
2. Tap Share/PDF button
3. PDF should generate
4. Share sheet should open

---

### Task 4: Test WhatsApp Sharing (30 minutes) 📱

**Integration Point**: Invoice detail screen (after PDF generation)

**Add WhatsApp option**:
```dart
Future<void> _shareViaWhatsApp() async {
  if (_invoiceData == null) return;
  
  final data = _invoiceData!['data'] as Map<String, dynamic>;
  
  // First generate PDF
  setState(() => _isLoading = true);
  
  try {
    // Generate PDF (reuse _generatePdf logic)
    final pdf = await _generatePdfFile(); // Extract PDF gen to separate method
    
    // Share via WhatsApp
    final success = await WhatsAppService.shareInvoice(
      phoneNumber: data['customer_phone'] ?? '',
      shopName: _shopName ?? 'Shop',
      invoiceNumber: data['invoice_number'],
      total: (data['total'] as num).toDouble(),
      pdfFile: pdf,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? 'Shared via WhatsApp' 
            : 'WhatsApp not available'),
          backgroundColor: success 
            ? AppTheme.successColor 
            : AppTheme.errorColor,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share error: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

**Add button**:
```dart
// In invoice detail
TextButton.icon(
  onPressed: _shareViaWhatsApp,
  icon: const Icon(Icons.send),
  label: const Text('WhatsApp'),
),
```

**Test**:
1. Create invoice with customer phone
2. Open invoice detail
3. Tap WhatsApp button
4. WhatsApp should open with PDF attached

---

### Task 5: Polish Dashboard with Real Data (30 minutes) 📊

**File to Edit**: `apps/mobile/lib/app.dart` (DashboardScreen widget)

**Changes Needed**:

Replace mock data with real queries:

```dart
class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  double _todaySales = 0;
  int _todayInvoices = 0;
  double _todayCash = 0;
  
  @override
  void initState() {
    super.initState();
    _loadTodayStats();
  }
  
  Future<void> _loadTodayStats() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      // Get tenant_id
      final membership = await supabase
          .from('memberships')
          .select('tenant_id')
          .eq('user_id', user.id)
          .single();
      
      final tenantId = membership['tenant_id'];
      
      // Get invoice entity
      final entityResponse = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'invoice')
          .single();
      
      final entityId = entityResponse['id'];
      
      // Get today's invoices
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final response = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', entityId)
          .gte('created_at', startOfDay.toIso8601String());
      
      final invoices = List<Map<String, dynamic>>.from(response);
      
      // Calculate stats
      double total = 0;
      double cash = 0;
      
      for (final invoice in invoices) {
        final data = invoice['data'] as Map<String, dynamic>;
        final amount = (data['total'] ?? 0).toDouble();
        total += amount;
        
        if (data['payment_mode'] == 'cash') {
          cash += amount;
        }
      }
      
      setState(() {
        _todaySales = total;
        _todayInvoices = invoices.length;
        _todayCash = cash;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodayStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Today's summary card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today\'s Sales',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat(
                                context,
                                '₹${_todaySales.toStringAsFixed(2)}',
                                'Total Sales',
                              ),
                              _buildStat(
                                context,
                                _todayInvoices.toString(),
                                'Invoices',
                              ),
                              _buildStat(
                                context,
                                '₹${_todayCash.toStringAsFixed(2)}',
                                'Cash',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ... rest of dashboard
                ],
              ),
            ),
    );
  }
  
  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
```

**Test**:
1. Generate a few invoices
2. Go to Home tab
3. Stats should show real numbers
4. Pull to refresh should update

---

## Verification Checklist

After completing all tasks:

- [ ] App compiles without errors
- [ ] `app_database.g.dart` exists
- [ ] Barcode scanner opens from billing
- [ ] Scanned product adds to cart
- [ ] PDF generates from invoice detail
- [ ] PDF share sheet opens
- [ ] WhatsApp opens with invoice
- [ ] Dashboard shows real sales numbers
- [ ] Pull to refresh works on dashboard

---

## Common Issues & Fixes

### Issue: "app_database.g.dart not found"
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: "Camera permission denied"
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

Request at runtime (already in barcode_scanner_screen.dart).

### Issue: "PDF generation fails"
Check:
- All data fields are non-null
- Intl package is imported
- Printing package is installed

### Issue: "WhatsApp not opening"
Check:
- WhatsApp is installed on device
- url_launcher permission in manifest
- Phone number format is correct (+91...)

---

## Testing After Completion

### Test Flow 1: Barcode to Invoice
1. Billing → Scan barcode
2. Product adds to cart
3. Generate invoice
4. Invoice detail → Share PDF
5. PDF opens in viewer

### Test Flow 2: Complete Credit Sale
1. Billing → Add products
2. Select Credit payment
3. Choose customer
4. Generate invoice
5. Invoice detail → Share via WhatsApp
6. WhatsApp opens with PDF

### Test Flow 3: Dashboard Accuracy
1. Generate 3 invoices (2 cash, 1 UPI)
2. Go to Home tab
3. Verify:
   - Total sales = sum of all 3
   - Invoices = 3
   - Cash = sum of 2 cash invoices

---

## Time Estimate

| Task | Estimated Time | Actual Time |
|------|----------------|-------------|
| Generate code | 5 min | ___ |
| Wire barcode | 1 hour | ___ |
| Integrate PDF | 1 hour | ___ |
| Test WhatsApp | 30 min | ___ |
| Polish dashboard | 30 min | ___ |
| **Total** | **3 hours** | ___ |

---

## Success Criteria

✅ App compiles and runs  
✅ All features from Task 1-5 working  
✅ No errors in console  
✅ Manual testing passes  
✅ Ready for production deployment  

---

## After Completion

1. Update README.md status to 100%
2. Create release builds
3. Follow [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
4. Deploy to beta testers
5. Gather feedback
6. Fix bugs
7. Production release

---

**Let's complete ShopOS! 🚀**

*Estimated completion: 2-3 hours from now*
