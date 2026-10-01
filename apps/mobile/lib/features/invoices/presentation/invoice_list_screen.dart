// Invoice list screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import 'invoice_detail_screen.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final _searchController = TextEditingController();
  List<InvoiceData> _invoices = [];
  List<InvoiceData> _filteredInvoices = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, paid, credit
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final membership = await supabase
          .from('memberships')
          .select('tenant_id')
          .eq('user_id', user.id)
          .single();

      final tenantId = membership['tenant_id'];

      final entityResponse = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'invoice')
          .single();

      final entityId = entityResponse['id'];

      // Build query with filters first, then order
      final query = supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', entityId);

      // Apply date filter before ordering
      final filteredQuery = _dateRange != null
          ? query
              .gte('created_at', _dateRange!.start.toIso8601String())
              .lte('created_at', _dateRange!.end.toIso8601String())
          : query;

      final response = await filteredQuery.order('created_at', ascending: false);

      final invoicesList = response.map((record) {
        final data = record['data'] as Map<String, dynamic>;
        return InvoiceData(
          id: record['id'],
          invoiceNumber: data['invoice_number'] ?? '',
          date: DateTime.parse(data['invoice_date'] ?? record['created_at']),
          total: (data['total'] ?? 0).toDouble(),
          paymentMode: data['payment_mode'] ?? 'cash',
          customerName: data['customer_name'],
          itemCount: (data['items'] as List?)?.length ?? 0,
        );
      }).toList();

      setState(() {
        _invoices = invoicesList;
        _filteredInvoices = invoicesList;
        _filterInvoices();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invoices: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _filterInvoices() {
    setState(() {
      _filteredInvoices = _invoices.where((invoice) {
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          if (!invoice.invoiceNumber.toLowerCase().contains(searchQuery) &&
              !(invoice.customerName?.toLowerCase().contains(searchQuery) ?? false)) {
            return false;
          }
        }

        // Status filter
        if (_filterStatus == 'paid' && invoice.paymentMode == 'credit') {
          return false;
        } else if (_filterStatus == 'credit' && invoice.paymentMode != 'credit') {
          return false;
        }

        return true;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadInvoices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _filteredInvoices.fold<double>(
      0,
      (sum, inv) => sum + inv.total,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
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
                        _filteredInvoices.length.toString(),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Invoices'),
                    ],
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Column(
                    children: [
                      Text(
                        '₹${totalAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Total'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search and filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search invoices...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterInvoices();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => _filterInvoices(),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Paid', 'paid'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Credit', 'credit'),
                      if (_dateRange != null) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}',
                          ),
                          onDeleted: () {
                            setState(() => _dateRange = null);
                            _loadInvoices();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Invoice list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No invoices found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _filteredInvoices[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InvoiceDetailScreen(
                                        invoiceId: invoice.id,
                                      ),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundColor: _getColorForPaymentMode(
                                    invoice.paymentMode,
                                  ).withOpacity(0.1),
                                  child: Icon(
                                    _getIconForPaymentMode(invoice.paymentMode),
                                    color: _getColorForPaymentMode(invoice.paymentMode),
                                  ),
                                ),
                                title: Text(invoice.invoiceNumber),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('dd MMM yyyy, hh:mm a').format(invoice.date),
                                    ),
                                    if (invoice.customerName != null)
                                      Text(
                                        invoice.customerName!,
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    Text(
                                      '${invoice.itemCount} items',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${invoice.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getColorForPaymentMode(
                                          invoice.paymentMode,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        invoice.paymentMode.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getColorForPaymentMode(invoice.paymentMode),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _filterInvoices();
        });
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
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

class InvoiceData {
  final String id;
  final String invoiceNumber;
  final DateTime date;
  final double total;
  final String paymentMode;
  final String? customerName;
  final int itemCount;

  InvoiceData({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.total,
    required this.paymentMode,
    this.customerName,
    required this.itemCount,
  });
}
