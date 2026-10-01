// Reports screen with real data
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // Today's data
  double _todaySales = 0;
  int _todayInvoices = 0;
  double _todayCash = 0;
  double _todayUpi = 0;
  
  // This week data
  List<DailySales> _weekSales = [];
  
  // Top products
  List<TopProduct> _topProducts = [];
  
  // Low stock
  List<LowStockItem> _lowStockItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
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
      final invoiceEntity = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'invoice')
          .single();

      final invoiceEntityId = invoiceEntity['id'];

      // Get product entity
      final productEntity = await supabase
          .from('entities')
          .select('id')
          .eq('name', 'product')
          .single();

      final productEntityId = productEntity['id'];

      // Today's date range
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Get today's invoices
      final todayInvoices = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', invoiceEntityId)
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String())
          .is_('deleted_at', null);

      // Calculate today's stats
      double totalSales = 0;
      double cashSales = 0;
      double upiSales = 0;
      final productSales = <String, ProductSalesData>{};

      for (final invoice in todayInvoices) {
        final data = invoice['data'] as Map<String, dynamic>;
        final total = (data['total'] ?? 0).toDouble();
        final paymentMode = data['payment_mode'] ?? 'cash';
        final items = data['items'] as List<dynamic>? ?? [];

        totalSales += total;
        if (paymentMode == 'cash') {
          cashSales += total;
        } else if (paymentMode == 'upi') {
          upiSales += total;
        }

        // Track product sales
        for (final item in items) {
          final productId = item['product_id'];
          final name = item['name'];
          final quantity = item['quantity'] ?? 0;
          final itemTotal = (item['total'] ?? 0).toDouble();

          if (productSales.containsKey(productId)) {
            productSales[productId]!.quantity += quantity;
            productSales[productId]!.revenue += itemTotal;
          } else {
            productSales[productId] = ProductSalesData(
              name: name,
              quantity: quantity,
              revenue: itemTotal,
            );
          }
        }
      }

      // Get week's data
      final weekStart = todayStart.subtract(const Duration(days: 6));
      final weekInvoices = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', invoiceEntityId)
          .gte('created_at', weekStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String())
          .is_('deleted_at', null);

      final dailySalesMap = <String, double>{};
      for (var i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        dailySalesMap[dateKey] = 0;
      }

      for (final invoice in weekInvoices) {
        final data = invoice['data'] as Map<String, dynamic>;
        final total = (data['total'] ?? 0).toDouble();
        final createdAt = DateTime.parse(invoice['created_at']);
        final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
        dailySalesMap[dateKey] = (dailySalesMap[dateKey] ?? 0) + total;
      }

      final weekSalesList = dailySalesMap.entries
          .map((e) => DailySales(
                date: DateTime.parse(e.key),
                amount: e.value,
              ))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      // Get low stock products
      final products = await supabase
          .from('records')
          .select()
          .eq('tenant_id', tenantId)
          .eq('entity_id', productEntityId)
          .is_('deleted_at', null);

      final lowStock = <LowStockItem>[];
      for (final product in products) {
        final data = product['data'] as Map<String, dynamic>;
        final stock = data['stock'] ?? 0;
        final minStock = data['min_stock'] ?? 5;
        if (stock <= minStock && stock > 0) {
          lowStock.add(LowStockItem(
            name: data['name'] ?? '',
            currentStock: stock,
            minStock: minStock,
          ));
        }
      }

      // Sort top products by revenue
      final topProductsList = productSales.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      setState(() {
        _todaySales = totalSales;
        _todayInvoices = todayInvoices.length;
        _todayCash = cashSales;
        _todayUpi = upiSales;
        _weekSales = weekSalesList;
        _topProducts = topProductsList
            .take(5)
            .map((p) => TopProduct(
                  name: p.name,
                  quantity: p.quantity,
                  revenue: p.revenue,
                ))
            .toList();
        _lowStockItems = lowStock;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
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
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Week'),
            Tab(text: 'Products'),
            Tab(text: 'Stock'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTodayTab(),
                  _buildWeekTab(),
                  _buildProductsTab(),
                  _buildStockTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildTodayTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Sales',
                '₹${_todaySales.toStringAsFixed(2)}',
                Icons.currency_rupee,
                AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Invoices',
                _todayInvoices.toString(),
                Icons.receipt,
                AppTheme.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Cash',
                '₹${_todayCash.toStringAsFixed(2)}',
                Icons.money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'UPI',
                '₹${_todayUpi.toStringAsFixed(2)}',
                Icons.qr_code,
                Colors.blue,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Top products today
        if (_topProducts.isNotEmpty) ...[
          Text(
            'Top Selling Today',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ..._topProducts.take(3).map((p) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: const Icon(Icons.star, color: AppTheme.primaryColor),
                  ),
                  title: Text(p.name),
                  subtitle: Text('Qty: ${p.quantity}'),
                  trailing: Text(
                    '₹${p.revenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildWeekTab() {
    final maxSales = _weekSales.isEmpty
        ? 1.0
        : _weekSales.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Last 7 Days',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        
        // Simple bar chart
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekSales.map((day) {
              final height = (day.amount / maxSales) * 180;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '₹${(day.amount / 1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 30,
                    height: height,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEE').format(day.date),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Weekly summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Sales:'),
                    Text(
                      '₹${_weekSales.fold<double>(0, (sum, day) => sum + day.amount).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daily Average:'),
                    Text(
                      '₹${(_weekSales.fold<double>(0, (sum, day) => sum + day.amount) / 7).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Top 5 Products',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        
        if (_topProducts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No sales data yet'),
            ),
          )
        else
          ..._topProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getColorForRank(index),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(product.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity sold: ${product.quantity}'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: product.revenue / _topProducts.first.revenue,
                      backgroundColor: Colors.grey[200],
                      color: _getColorForRank(index),
                    ),
                  ],
                ),
                trailing: Text(
                  '₹${product.revenue.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getColorForRank(index),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStockTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Low Stock Alert',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        
        if (_lowStockItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('All products are well stocked!'),
                ],
              ),
            ),
          )
        else
          ..._lowStockItems.map((item) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.warningColor.withOpacity(0.1),
                    child: const Icon(
                      Icons.warning_amber,
                      color: AppTheme.warningColor,
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    'Min stock: ${item.minStock}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.currentStock} left',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForRank(int rank) {
    switch (rank) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return AppTheme.primaryColor;
    }
  }
}

// Data models
class DailySales {
  final DateTime date;
  final double amount;

  DailySales({required this.date, required this.amount});
}

class TopProduct {
  final String name;
  final int quantity;
  final double revenue;

  TopProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

class LowStockItem {
  final String name;
  final int currentStock;
  final int minStock;

  LowStockItem({
    required this.name,
    required this.currentStock,
    required this.minStock,
  });
}

class ProductSalesData {
  final String name;
  int quantity;
  double revenue;

  ProductSalesData({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}
