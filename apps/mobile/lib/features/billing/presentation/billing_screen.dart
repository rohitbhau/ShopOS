// Billing/POS screen - works offline
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

import '../../../core/theme/app_theme.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final List<CartItem> _cart = [];
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoadingProducts = true;
  String _paymentMode = 'cash';
  String? _selectedCustomerId;
  String? _selectedCustomerName;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);

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

      // Get product entity
      final entityResponse = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'product')
          .single();

      final entityId = entityResponse['id'];

      // Get products with stock > 0
      final response = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', entityId)
          
          .order('created_at', ascending: false);

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _filteredProducts = _products;
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() => _isLoadingProducts = false);
    }
  }

  void _searchProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((product) {
          final data = product['data'] as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final sku = (data['sku'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) ||
              sku.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    final data = product['data'] as Map<String, dynamic>;
    final existingIndex = _cart.indexWhere(
      (item) => item.productId == product['id'],
    );

    setState(() {
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(CartItem(
          productId: product['id'],
          name: data['name'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          gstRate: double.parse((data['gst_rate'] ?? '18').toString()),
          quantity: 1,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${data['name']} added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  double _getSubtotal() {
    return _cart.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double _getTotalTax() {
    return _cart.fold(0, (sum, item) {
      final itemTotal = item.price * item.quantity;
      return sum + (itemTotal * item.gstRate / 100);
    });
  }

  double _getGrandTotal() {
    return _getSubtotal() + _getTotalTax();
  }

  Future<void> _generateInvoice() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Validate customer selection for credit sales
    if (_paymentMode == 'credit' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer for credit sale'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) throw Exception('Not authenticated');

      // Get tenant_id
      final membership = await supabase
          .from('memberships')
          .select('tenant_id')
          .eq('user_id', user.id)
          .single();

      final tenantId = membership['tenant_id'];

      // Get invoice entity_id
      final entityResponse = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'invoice')
          .single();

      final entityId = entityResponse['id'];

      // Generate invoice number (device-prefix + timestamp)
      final deviceId = Random().nextInt(9999).toString().padLeft(4, '0');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final invoiceNumber = 'INV-$deviceId-$timestamp';

      final invoiceTotal = _getGrandTotal();

      // Prepare invoice data
      final invoiceData = {
        'invoice_number': invoiceNumber,
        'invoice_date': DateTime.now().toIso8601String(),
        'customer_id': _selectedCustomerId,
        'customer_name': _selectedCustomerName,
        'items': _cart.map((item) => {
          'product_id': item.productId,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'gst_rate': item.gstRate,
          'total': item.price * item.quantity,
        }).toList(),
        'subtotal': _getSubtotal(),
        'tax_amount': _getTotalTax(),
        'total': invoiceTotal,
        'payment_mode': _paymentMode,
        'payment_status': _paymentMode == 'credit' ? 'pending' : 'paid',
      };

      // Save invoice
      await supabase.from('records').insert({
        'id': const Uuid().v4(),
        'tenant_id': tenantId,
        'entity_id': entityId,
        'data': invoiceData,
        'created_by': user.id,
      });

      // Update stock for each product
      for (final item in _cart) {
        final productResponse = await supabase
            .from('records')
            .select()
            .eq('id', item.productId)
            .single();

        final productData = productResponse['data'] as Map<String, dynamic>;
        final currentStock = productData['stock'] ?? 0;
        final newStock = currentStock - item.quantity;

        await supabase
            .from('records')
            .update({
              'data': {...productData, 'stock': newStock},
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', item.productId);
      }

      // If credit sale, update customer outstanding
      if (_paymentMode == 'credit' && _selectedCustomerId != null) {
        // Get customer entity_id
        final customerEntityResponse = await supabase
            .from('entities')
            .select('id')
            .eq('name', 'customer')
            .single();

        final customerEntityId = customerEntityResponse['id'];

        // Get customer record
        final customerId = _selectedCustomerId!; // Non-null assertion safe here
        final customerResponse = await supabase
            .from('records')
            .select()
            .eq('id', customerId)
            .single();

        final customerData = customerResponse['data'] as Map<String, dynamic>;
        final currentOutstanding = (customerData['outstanding'] ?? 0).toDouble();
        final newOutstanding = currentOutstanding + invoiceTotal;

        // Update customer outstanding
        await supabase
            .from('records')
            .update({
              'data': {...customerData, 'outstanding': newOutstanding},
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', customerId);

        // Add transaction to ledger
        final ledger = List<Map<String, dynamic>>.from(customerData['ledger'] ?? []);
        ledger.insert(0, {
          'date': DateTime.now().toIso8601String(),
          'type': 'sale',
          'invoice_number': invoiceNumber,
          'description': 'Credit sale',
          'debit': invoiceTotal,
          'credit': 0,
          'balance': newOutstanding,
        });

        // Update ledger (keep only last 100 transactions)
        if (ledger.length > 100) {
          ledger.removeRange(100, ledger.length);
        }

        await supabase
            .from('records')
            .update({
              'data': {...customerData, 'ledger': ledger, 'outstanding': newOutstanding},
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', customerId);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show success
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor),
                SizedBox(width: 8),
                Text('Invoice Generated'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice #: $invoiceNumber'),
                const SizedBox(height: 8),
                Text('Total: ₹${invoiceTotal.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Payment: ${_paymentMode.toUpperCase()}'),
                if (_paymentMode == 'credit')
                  Text(
                    'Outstanding added to ${_selectedCustomerName}',
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('View Invoice'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _cart.clear();
                    _paymentMode = 'cash';
                    _selectedCustomerId = null;
                    _selectedCustomerName = null;
                  });
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _selectCustomer() async {
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

      // Get customer entity_id
      final entityResponse = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'customer')
          .single();

      final entityId = entityResponse['id'];

      // Get customers
      final response = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', entityId)
          
          .order('created_at', ascending: false);

      final customers = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Customer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                final data = customer['data'] as Map<String, dynamic>;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(data['name'] ?? ''),
                  subtitle: Text(data['phone'] ?? ''),
                  onTap: () => Navigator.pop(context, customer),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selected != null) {
        final data = selected['data'] as Map<String, dynamic>;
        setState(() {
          _selectedCustomerId = selected['id'];
          _selectedCustomerName = data['name'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load customers: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                setState(() => _cart.clear());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Product search
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Barcode scanner coming soon'),
                      ),
                    );
                  },
                ),
              ),
              onChanged: _searchProducts,
            ),
          ),

          // Product list (if searching)
          if (_searchController.text.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final data = product['data'] as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.inventory),
                          title: Text(data['name'] ?? ''),
                          subtitle: Text('₹${data['price']}'),
                          trailing: Text('Stock: ${data['stock']}'),
                          onTap: () {
                            _addToCart(product);
                            _searchController.clear();
                            _searchProducts('');
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
            ),

          // Cart items
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cart is empty',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search and add products',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${item.price} × ${item.quantity} = ₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => _updateQuantity(index, -1),
                                    color: AppTheme.errorColor,
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => _updateQuantity(index, 1),
                                    color: AppTheme.successColor,
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeFromCart(index),
                                color: AppTheme.errorColor,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom summary
          if (_cart.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Customer selection (for credit sales)
                  if (_paymentMode == 'credit')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: _selectCustomer,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedCustomerName ?? 'Select Customer',
                                  style: TextStyle(
                                    color: _selectedCustomerName != null
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Payment mode
                  Row(
                    children: [
                      const Text('Payment: '),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'cash', label: Text('Cash')),
                            ButtonSegment(value: 'upi', label: Text('UPI')),
                            ButtonSegment(value: 'card', label: Text('Card')),
                            ButtonSegment(value: 'credit', label: Text('Credit')),
                          ],
                          selected: {_paymentMode},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _paymentMode = newSelection.first;
                              if (_paymentMode != 'credit') {
                                _selectedCustomerId = null;
                                _selectedCustomerName = null;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text('₹${_getSubtotal().toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax (GST):'),
                      Text('₹${_getTotalTax().toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '₹${_getGrandTotal().toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _generateInvoice,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Generate Invoice'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Cart item model
class CartItem {
  final String productId;
  final String name;
  final double price;
  final double gstRate;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.gstRate,
    required this.quantity,
  });
}
