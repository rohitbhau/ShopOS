// Add/Edit product screen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  final Map<String, dynamic>? initialData;

  const AddProductScreen({
    Key? key,
    this.productId,
    this.initialData,
  }) : super(key: key);

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();

  String _selectedGst = '18';
  bool _isLoading = false;

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadInitialData();
    } else {
      _minStockController.text = '5';
      _stockController.text = '0';
    }
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    _nameController.text = data['name'] ?? '';
    _skuController.text = data['sku'] ?? '';
    _priceController.text = (data['price'] ?? 0).toString();
    _costController.text = (data['cost'] ?? 0).toString();
    _stockController.text = (data['stock'] ?? 0).toString();
    _minStockController.text = (data['min_stock'] ?? 5).toString();
    _selectedGst = (data['gst_rate'] ?? '18').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

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

      // Get product entity_id
      final entityResponse = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'product')
          .single();

      final entityId = entityResponse['id'];

      // Prepare data
      final productData = {
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        'price': double.parse(_priceController.text),
        'cost': _costController.text.isEmpty
            ? 0
            : double.parse(_costController.text),
        'stock': int.parse(_stockController.text),
        'min_stock': int.parse(_minStockController.text),
        'gst_rate': _selectedGst,
      };

      if (isEditing) {
        // Update existing product
        await supabase
            .from('records')
            .update({
              'data': productData,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.productId!);
      } else {
        // Create new product
        await supabase.from('records').insert({
          'id': const Uuid().v4(),
          'tenant_id': tenantId,
          'entity_id': entityId,
          'data': productData,
          'created_by': user.id,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'Product updated' : 'Product added',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'Tata Salt 1kg',
                prefixIcon: Icon(Icons.label),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // SKU/Barcode
            TextFormField(
              controller: _skuController,
              decoration: InputDecoration(
                labelText: 'SKU/Barcode',
                hintText: '1234567890',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {
                    // TODO: Barcode scanner
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Barcode scanner coming soon'),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Selling Price *',
                hintText: '50.00',
                prefixIcon: Icon(Icons.currency_rupee),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter price';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter valid price';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Cost price
            TextFormField(
              controller: _costController,
              decoration: const InputDecoration(
                labelText: 'Cost Price (Optional)',
                hintText: '40.00',
                prefixIcon: Icon(Icons.attach_money),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),

            const SizedBox(height: 16),

            // Stock quantity
            TextFormField(
              controller: _stockController,
              decoration: const InputDecoration(
                labelText: 'Current Stock *',
                hintText: '100',
                prefixIcon: Icon(Icons.inventory_2),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter stock quantity';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Minimum stock
            TextFormField(
              controller: _minStockController,
              decoration: const InputDecoration(
                labelText: 'Minimum Stock Level *',
                hintText: '5',
                prefixIcon: Icon(Icons.warning_amber),
                helperText: 'Alert when stock falls below this level',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter minimum stock level';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // GST Rate
            DropdownButtonFormField<String>(
              initialValue: _selectedGst,
              decoration: const InputDecoration(
                labelText: 'GST Rate',
                prefixIcon: Icon(Icons.percent),
              ),
              items: ['0', '5', '12', '18', '28'].map((rate) {
                return DropdownMenuItem(
                  value: rate,
                  child: Text('$rate%'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedGst = value!);
              },
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEditing ? 'Update Product' : 'Add Product'),
              ),
            ),

            if (isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
