// Customer detail screen with ledger
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerDetailScreen({
    Key? key,
    required this.customerId,
    required this.customerName,
  }) : super(key: key);

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  bool _isLoading = true;
  double _outstanding = 0;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get customer data
      final customerResponse = await supabase
          .from('records')
          .select()
          .eq('id', widget.customerId)
          .single();

      final customerData = customerResponse['data'] as Map<String, dynamic>;
      final outstanding = (customerData['outstanding'] ?? 0).toDouble();

      // Get membership for tenant_id
      final membership = await supabase
          .from('memberships')
          .select('tenant_id')
          .eq('user_id', user.id)
          .single();

      final tenantId = membership['tenant_id'];

      // Get invoice entity
      final invoiceEntity = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'invoice')
          .single();

      final invoiceEntityId = invoiceEntity['id'];

      // Get all invoices for this customer (credit sales)
      final invoices = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', invoiceEntityId)
          .is_('deleted_at', null)
          .order('created_at', ascending: false);

      final transactionsList = <Transaction>[];
      for (final invoice in invoices) {
        final data = invoice['data'] as Map<String, dynamic>;
        final customerId = data['customer_id'];
        
        if (customerId == widget.customerId && data['payment_mode'] == 'credit') {
          transactionsList.add(Transaction(
            date: DateTime.parse(invoice['created_at']),
            type: 'credit_sale',
            amount: (data['total'] ?? 0).toDouble(),
            description: 'Invoice ${data['invoice_number']}',
          ));
        }
      }

      setState(() {
        _outstanding = outstanding;
        _transactions = transactionsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _recordPayment() async {
    final amountController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Outstanding: ₹${_outstanding.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount Received',
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid amount'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              if (amount > _outstanding) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Amount cannot exceed outstanding'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final amount = double.parse(amountController.text);

    try {
      final supabase = Supabase.instance.client;

      // Get current customer data
      final customerResponse = await supabase
          .from('records')
          .select()
          .eq('id', widget.customerId)
          .single();

      final customerData = customerResponse['data'] as Map<String, dynamic>;
      final newOutstanding = _outstanding - amount;

      // Update outstanding
      await supabase
          .from('records')
          .update({
            'data': {...customerData, 'outstanding': newOutstanding},
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.customerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        
        setState(() {
          _outstanding = newOutstanding;
          _transactions.insert(
            0,
            Transaction(
              date: DateTime.now(),
              type: 'payment',
              amount: amount,
              description: 'Payment received',
            ),
          );
        });
      }
    } catch (e) {
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
        title: Text(widget.customerName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Outstanding card
                Card(
                  margin: const EdgeInsets.all(16),
                  color: _outstanding > 0
                      ? AppTheme.errorColor.withOpacity(0.1)
                      : AppTheme.successColor.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Outstanding Balance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${_outstanding.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: _outstanding > 0
                                    ? AppTheme.errorColor
                                    : AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (_outstanding > 0) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _recordPayment,
                              icon: const Icon(Icons.payment),
                              label: const Text('Record Payment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Transactions list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Transaction History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${_transactions.length} transactions',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: _transactions.isEmpty
                      ? const Center(
                          child: Text('No transactions yet'),
                        )
                      : ListView.builder(
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            final isPayment = transaction.type == 'payment';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPayment
                                      ? AppTheme.successColor.withOpacity(0.1)
                                      : AppTheme.errorColor.withOpacity(0.1),
                                  child: Icon(
                                    isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isPayment
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                  ),
                                ),
                                title: Text(transaction.description),
                                subtitle: Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(transaction.date),
                                ),
                                trailing: Text(
                                  '${isPayment ? '-' : '+'}₹${transaction.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPayment
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// Transaction model
class Transaction {
  final DateTime date;
  final String type; // 'credit_sale', 'payment'
  final double amount;
  final String description;

  Transaction({
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
  });
}
