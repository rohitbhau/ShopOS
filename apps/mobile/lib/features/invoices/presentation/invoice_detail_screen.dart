// Invoice detail screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({
    Key? key,
    required this.invoiceId,
  }) : super(key: key);

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _invoiceData;
  String? _shopName;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get invoice
      final invoiceResponse = await supabase
          .from('records')
          .select()
          .eq('id', widget.invoiceId)
          .single();

      // Get shop name
      final membership = await supabase
          .from('memberships')
          .select('tenant_id')
          .eq('user_id', user.id)
          .single();

      final tenantResponse = await supabase
          .from('tenants')
          .select('name')
          .eq('id', membership['tenant_id'])
          .single();

      setState(() {
        _invoiceData = invoiceResponse['data'];
        _shopName = tenantResponse['name'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invoice: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _shareInvoice() {
    if (_invoiceData == null) return;

    final text = '''
$_shopName
Invoice #${_invoiceData!['invoice_number']}
Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(_invoiceData!['invoice_date']))}

Items:
${(_invoiceData!['items'] as List).map((item) => '${item['name']} x ${item['quantity']} = ₹${item['total']}').join('\n')}

Subtotal: ₹${_invoiceData!['subtotal']}
Tax: ₹${_invoiceData!['tax_amount']}
Total: ₹${_invoiceData!['total']}

Payment: ${_invoiceData!['payment_mode'].toString().toUpperCase()}
''';

    Share.share(text, subject: 'Invoice ${_invoiceData!['invoice_number']}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoiceData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    final items = _invoiceData!['items'] as List;
    final subtotal = (_invoiceData!['subtotal'] ?? 0).toDouble();
    final tax = (_invoiceData!['tax_amount'] ?? 0).toDouble();
    final total = (_invoiceData!['total'] ?? 0).toDouble();
    final paymentMode = _invoiceData!['payment_mode'] ?? 'cash';
    final invoiceDate = DateTime.parse(_invoiceData!['invoice_date']);

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoiceData!['invoice_number']),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Print feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop header
            Center(
              child: Column(
                children: [
                  Text(
                    _shopName ?? '',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invoice #${_invoiceData!['invoice_number']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(invoiceDate),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            const Divider(height: 32),

            // Items table
            Text(
              'Items',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            ...items.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '₹${(item['total'] ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${item['quantity']} × ₹${item['price']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (item['gst_rate'] != null && item['gst_rate'] > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'GST ${item['gst_rate']}%',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            // Totals
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _buildTotalRow('Subtotal', subtotal),
                  const SizedBox(height: 8),
                  _buildTotalRow('Tax (GST)', tax),
                  const Divider(height: 16),
                  _buildTotalRow(
                    'Grand Total',
                    total,
                    isBold: true,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment info
            Card(
              color: _getColorForPaymentMode(paymentMode).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _getIconForPaymentMode(paymentMode),
                      color: _getColorForPaymentMode(paymentMode),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Payment: ${paymentMode.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _getColorForPaymentMode(paymentMode),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Center(
              child: Text(
                'Thank you for your business!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
            color: color,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 18 : 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getColorForPaymentMode(String mode) {
    switch (mode) {
      case 'cash':
        return Colors.green;
      case 'upi':
        return Colors.blue;
      case 'card':
        return Colors.purple;
      case 'credit':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForPaymentMode(String mode) {
    switch (mode) {
      case 'cash':
        return Icons.money;
      case 'upi':
        return Icons.qr_code;
      case 'card':
        return Icons.credit_card;
      case 'credit':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }
}
