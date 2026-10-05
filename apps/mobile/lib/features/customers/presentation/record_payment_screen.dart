// Record payment screen for partial/full payments
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final double outstandingAmount;

  const RecordPaymentScreen({
    Key? key,
    required this.customerId,
    required this.customerName,
    required this.outstandingAmount,
  }) : super(key: key);

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMode = 'cash';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.outstandingAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final amount = double.parse(_amountController.text);

      // Get customer record
      final customerResponse = await supabase
          .from('records')
          .select()
          .eq('id', widget.customerId)
          .single();

      final customerData = customerResponse['data'] as Map<String, dynamic>;
      final currentOutstanding = (customerData['outstanding'] ?? 0).toDouble();
      final newOutstanding = currentOutstanding - amount;

      // Update ledger
      final ledger = List<Map<String, dynamic>>.from(customerData['ledger'] ?? []);
      ledger.insert(0, {
        'date': DateTime.now().toIso8601String(),
        'type': 'payment',
        'description': _notesController.text.isEmpty 
            ? 'Payment received via ${_paymentMode.toUpperCase()}'
            : _notesController.text,
        'debit': 0,
        'credit': amount,
        'balance': newOutstanding > 0 ? newOutstanding : 0,
        'payment_mode': _paymentMode,
      });

      if (ledger.length > 100) {
        ledger.removeRange(100, ledger.length);
      }

      // Update customer
      await supabase.from('records').update({
        'data': {
          ...customerData,
          'outstanding': newOutstanding > 0 ? newOutstanding : 0,
          'ledger': ledger,
        },
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.customerId);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${amount.toStringAsFixed(2)} recorded'),
            backgroundColor: AppTheme.successColor,
          ),
        );
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customerName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Outstanding Amount:'),
                        Text(
                          '₹${widget.outstandingAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Amount field
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Payment Amount *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter valid amount';
                }
                if (amount > widget.outstandingAmount) {
                  return 'Amount cannot exceed outstanding';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Quick amount buttons
            Wrap(
              spacing: 8,
              children: [
                _buildQuickAmountButton(widget.outstandingAmount / 4, '25%'),
                _buildQuickAmountButton(widget.outstandingAmount / 2, '50%'),
                _buildQuickAmountButton(widget.outstandingAmount * 0.75, '75%'),
                _buildQuickAmountButton(widget.outstandingAmount, 'Full'),
              ],
            ),
            const SizedBox(height: 24),

            // Payment mode
            const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash')),
                ButtonSegment(value: 'upi', label: Text('UPI')),
                ButtonSegment(value: 'card', label: Text('Card')),
                ButtonSegment(value: 'cheque', label: Text('Cheque')),
              ],
              selected: {_paymentMode},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _paymentMode = newSelection.first);
              },
            ),
            const SizedBox(height: 24),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _recordPayment,
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(double amount, String label) {
    return OutlinedButton(
      onPressed: () {
        _amountController.text = amount.toStringAsFixed(2);
      },
      child: Text(label),
    );
  }
}
