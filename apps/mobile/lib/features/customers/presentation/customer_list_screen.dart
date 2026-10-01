// Customer list screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  List<CustomerData> _customers = [];
  List<CustomerData> _filteredCustomers = [];
  bool _isLoading = true;
  String _sortBy = 'name'; // name, outstanding

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
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

      // Get customer entity
      final entityResponse = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'customer')
          .single();

      final entityId = entityResponse['id'];

      // Get all customers
      final response = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', entityId)
          
          .order('created_at', ascending: false);

      final customersList = response.map((record) {
        final data = record['data'] as Map<String, dynamic>;
        return CustomerData(
          id: record['id'],
          name: data['name'] ?? '',
          phone: data['phone'] ?? '',
          email: data['email'] ?? '',
          outstanding: (data['outstanding'] ?? 0).toDouble(),
        );
      }).toList();

      setState(() {
        _customers = customersList;
        _filteredCustomers = customersList;
        _sortCustomers();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading customers: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _searchCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        _filteredCustomers = _customers.where((customer) {
          final name = customer.name.toLowerCase();
          final phone = customer.phone.toLowerCase();
          return name.contains(query.toLowerCase()) ||
              phone.contains(query.toLowerCase());
        }).toList();
      }
      _sortCustomers();
    });
  }

  void _sortCustomers() {
    _filteredCustomers.sort((a, b) {
      if (_sortBy == 'outstanding') {
        return b.outstanding.compareTo(a.outstanding);
      } else {
        return a.name.compareTo(b.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totals
    final totalOutstanding = _customers.fold<double>(
      0,
      (sum, customer) => sum + customer.outstanding,
    );
    final customersWithCredit = _customers.where((c) => c.outstanding > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: Column(
        children: [
          // Summary card
          Card(
            margin: const EdgeInsets.all(16),
            color: AppTheme.primaryColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        _customers.length.toString(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Total'),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Column(
                    children: [
                      Text(
                        customersWithCredit.toString(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text('With Credit'),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Column(
                    children: [
                      Text(
                        '₹${totalOutstanding.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Outstanding'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search and sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _searchCustomers('');
                              },
                            )
                          : null,
                    ),
                    onChanged: _searchCustomers,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  onSelected: (value) {
                    setState(() {
                      _sortBy = value;
                      _sortCustomers();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'name',
                      child: Text('Sort by Name'),
                    ),
                    const PopupMenuItem(
                      value: 'outstanding',
                      child: Text('Sort by Outstanding'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Customer list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No customers found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first customer',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCustomers,
                        child: ListView.builder(
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CustomerDetailScreen(
                                        customerId: customer.id,
                                        customerName: customer.name,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadCustomers();
                                  }
                                },
                                leading: CircleAvatar(
                                  backgroundColor: customer.outstanding > 0
                                      ? AppTheme.errorColor.withOpacity(0.1)
                                      : AppTheme.successColor.withOpacity(0.1),
                                  child: Icon(
                                    Icons.person,
                                    color: customer.outstanding > 0
                                        ? AppTheme.errorColor
                                        : AppTheme.successColor,
                                  ),
                                ),
                                title: Text(customer.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (customer.phone.isNotEmpty)
                                      Text(customer.phone),
                                    if (customer.outstanding > 0) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.errorColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Outstanding: ₹${customer.outstanding.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.errorColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCustomerScreen(),
            ),
          );
          if (result == true) {
            _loadCustomers();
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }
}

// Data model
class CustomerData {
  final String id;
  final String name;
  final String phone;
  final String email;
  final double outstanding;

  CustomerData({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.outstanding,
  });
}
