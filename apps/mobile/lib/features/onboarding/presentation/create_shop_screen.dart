// Create shop onboarding screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

class CreateShopScreen extends ConsumerStatefulWidget {
  const CreateShopScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends ConsumerState<CreateShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  
  String _selectedType = 'retail';
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, Map<String, dynamic>> _shopTypes = {
    'retail': {
      'label': 'Retail / Kirana',
      'icon': Icons.store,
      'template': 'retail_basic',
    },
    'pharmacy': {
      'label': 'Pharmacy',
      'icon': Icons.local_pharmacy,
      'template': 'pharmacy',
    },
    'salon': {
      'label': 'Salon',
      'icon': Icons.content_cut,
      'template': 'salon',
    },
    'restaurant': {
      'label': 'Restaurant',
      'icon': Icons.restaurant,
      'template': 'restaurant',
    },
    'boutique': {
      'label': 'Boutique',
      'icon': Icons.checkroom,
      'template': 'boutique',
    },
    'repair': {
      'label': 'Repair Shop',
      'icon': Icons.build,
      'template': 'repair',
    },
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _createShop() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Step 1: Create or update profile
      await supabase.from('profiles').upsert({
        'id': user.id,
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'name': _nameController.text.trim(),
      }, onConflict: 'id');

      // Step 2: Create tenant (shop)
      final tenantResponse = await supabase.from('tenants').insert({
        'name': _nameController.text.trim(),
        'shop_type': _selectedType,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gstin': _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
        'is_active': true,
      }).select().single();

      final tenantId = tenantResponse['id'];

      // Step 3: Create membership (link user to tenant as owner)
      await supabase.from('memberships').insert({
        'tenant_id': tenantId,
        'user_id': user.id,
        'role': 'owner',
        'is_active': true,
      });

      if (!mounted) return;
      
      // Show success and navigate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop created successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Small delay to let user see success message
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      context.go('/home');
      
    } on PostgrestException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Database error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to create shop: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Shop'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress indicator
            Text(
              'Step 1 of 1',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.grey[200],
              color: AppTheme.primaryColor,
            ),
            
            const SizedBox(height: 24),
            
            // Shop name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Shop Name *',
                hintText: 'Raj Kirana Store',
                prefixIcon: Icon(Icons.store),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter shop name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Shop type
            Text(
              'Shop Type *',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: _shopTypes.entries.map((entry) {
                final isSelected = _selectedType == entry.key;
                return InkWell(
                  onTap: () => setState(() => _selectedType = entry.key),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.white,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          entry.value['icon'] as IconData,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value['label'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[600],
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Phone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '9876543210',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 16),
            
            // Address
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Shop address',
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // GSTIN
            TextFormField(
              controller: _gstinController,
              decoration: const InputDecoration(
                labelText: 'GSTIN (Optional)',
                hintText: '29XXXXX1234X1XX',
                prefixIcon: Icon(Icons.receipt),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            
            const SizedBox(height: 24),
            
            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorColor),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Create button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createShop,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Shop'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
