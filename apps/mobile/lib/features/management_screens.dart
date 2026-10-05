import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/permissions.dart';
import '../data/local/shop_store.dart';
import '../domain/shop_models.dart';
import 'shop_screens.dart' show editRecord, perform, rupees, confirm;

class CustomersPage extends StatefulWidget {
  const CustomersPage({required this.store, this.client, super.key});
  final ShopStore store; final SupabaseClient? client;
  @override State<CustomersPage> createState() => _CustomersPageState();
}
class _CustomersPageState extends State<CustomersPage> {
  String query = '';
  Future<void> edit([Customer? customer]) async {
    final values = await editRecord(context, title: customer == null ? 'Add customer' : 'Edit customer', entity: 'customer', fields: customerFields, initial: customer?.toJson());
    if (values != null && mounted) await perform(context, () => widget.store.saveCustomer(values, id: customer?.id));
  }
  Future<void> details(Customer customer) async {
    final store = widget.store;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (sheet) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheet).viewInsets.bottom + 24), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(customer.name, style: Theme.of(sheet).textTheme.headlineSmall), const SizedBox(height: 8), Text(customer.phone), const SizedBox(height: 12), Text('Outstanding: ${rupees(customer.outstanding)}'), const SizedBox(height: 20),
      if (customer.outstanding > 0 && can(store.role, ShopPermission.createInvoice)) FilledButton.icon(onPressed: () async { Navigator.pop(sheet); await payment(customer); }, icon: const Icon(Icons.payments_outlined), label: const Text('Record payment')),
      const SizedBox(height: 16), Text('Credit ledger', style: Theme.of(sheet).textTheme.titleLarge),
      if (!(store.records['ledger'] ?? []).any((row) => row['customer_id'] == customer.id)) const Padding(padding: EdgeInsets.all(16), child: Text('Credit sales and payments will appear here.')),
      ...(store.records['ledger'] ?? []).where((row) => row['customer_id'] == customer.id).toList().reversed.map((row) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(row['type'] == 'credit_sale' ? Icons.receipt_long : Icons.check_circle_outline), title: Text(row['type'] == 'credit_sale' ? 'Credit sale' : 'Payment received'), subtitle: Text('${row['created_at']}'), trailing: Text(rupees(number(row['amount']))))),
    ])))));
  }
  Future<void> payment(Customer customer) async {
    final amount = TextEditingController(text: customer.outstanding.toStringAsFixed(2));
    String mode = 'cash'; bool verified = false;
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, update) => AlertDialog(title: Text('Payment from ${customer.name}'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Outstanding ${rupees(customer.outstanding)}'), const SizedBox(height: 16), TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount received')),
      const SizedBox(height: 16), DropdownButtonFormField<String>(initialValue: mode, decoration: const InputDecoration(labelText: 'Payment method'), items: const ['cash', 'upi', 'card'].map((value) => DropdownMenuItem(value: value, child: Text(value.toUpperCase()))).toList(), onChanged: (value) => update(() { mode = value!; verified = false; })),
      if (mode != 'cash') CheckboxListTile(value: verified, onChanged: (value) => update(() => verified = value!), title: const Text('I verified receipt of payment')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')), FilledButton(onPressed: mode != 'cash' && !verified ? null : () => Navigator.pop(dialog, {'amount': amount.text, 'mode': mode}), child: const Text('Save payment'))])));
    amount.dispose();
    if (result != null && mounted) await perform(context, () => widget.store.receivePayment(customer, double.parse(result['amount']), mode: result['mode']));
  }
  @override Widget build(BuildContext context) {
    final customers = widget.store.customers.where((c) => '${c.name} ${c.phone}'.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [Row(children: [Expanded(child: Text('Customers', style: Theme.of(context).textTheme.headlineSmall)), if (can(widget.store.role, ShopPermission.createInvoice)) FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Add'))]), const SizedBox(height: 16), TextField(decoration: const InputDecoration(labelText: 'Search name or phone', prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => query = value)), const SizedBox(height: 16),
      if (customers.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Add a customer to keep their details and credit balance together.')),
      ...customers.map((customer) => Card(child: ListTile(leading: CircleAvatar(child: Text(customer.name.isEmpty ? '?' : customer.name[0])), title: Text(customer.name), subtitle: Text('${customer.phone}\nOutstanding: ${rupees(customer.outstanding)}'), isThreeLine: true, onTap: () => details(customer), trailing: can(widget.store.role, ShopPermission.createInvoice) ? IconButton(tooltip: 'Edit customer', icon: const Icon(Icons.edit_outlined), onPressed: () => edit(customer)) : null))),
    ]);
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.store, super.key}); final ShopStore store;
  @override State<ReportsPage> createState() => _ReportsPageState();
}
class _ReportsPageState extends State<ReportsPage> {
  int days = 7;
  @override Widget build(BuildContext context) {
    if (!can(widget.store.role, ShopPermission.viewReports)) return const Scaffold(body: Center(child: Text('Your role does not allow reports.')));
    final now = DateTime.now(), start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(Duration(days: days - 1));
    final invoices = widget.store.invoices.where((i) => !i.createdAt.toLocal().isBefore(start) && !i.createdAt.isAfter(now)).toList();
    final sales = invoices.fold<double>(0, (sum, i) => sum + i.total), profit = invoices.fold<double>(0, (sum, i) => sum + i.profit);
    final top = <String, double>{};
    for (final invoice in invoices) { for (final line in invoice.lines) { top[line.product.name] = (top[line.product.name] ?? 0) + line.total; } }
    final ranked = top.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(appBar: AppBar(title: const Text('Reports')), body: ListView(padding: const EdgeInsets.all(20), children: [
      SegmentedButton<int>(segments: const [ButtonSegment(value: 1, label: Text('Today')), ButtonSegment(value: 7, label: Text('Week')), ButtonSegment(value: 30, label: Text('30 days'))], selected: {days}, onSelectionChanged: (value) => setState(() => days = value.first)), const SizedBox(height: 20),
      Card(child: ListTile(title: const Text('Sales'), subtitle: Text('${invoices.length} invoices'), trailing: Text(rupees(sales), style: Theme.of(context).textTheme.titleLarge))),
      Card(child: ListTile(title: const Text('Estimated gross profit'), subtitle: const Text('Before shop operating expenses'), trailing: Text(rupees(profit)))), const SizedBox(height: 20),
      Text('Payment mix', style: Theme.of(context).textTheme.titleLarge), ...['cash', 'upi', 'card', 'credit'].map((mode) => ListTile(title: Text(mode.toUpperCase()), trailing: Text(rupees(invoices.where((i) => i.paymentMode == mode).fold<double>(0, (sum, i) => sum + i.total))))),
      const SizedBox(height: 20), Text('Top products', style: Theme.of(context).textTheme.titleLarge), if (ranked.isEmpty) const ListTile(title: Text('Create a sale to see your top products.')), ...ranked.take(10).map((entry) => ListTile(title: Text(entry.key), trailing: Text(rupees(entry.value)))),
      const SizedBox(height: 20), Text('Low stock', style: Theme.of(context).textTheme.titleLarge), ...widget.store.products.where((p) => p.isLowStock).map((p) => ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text(p.name), trailing: Text('${p.stock} left'))),
    ]));
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.store, this.client, required this.onSignOut, super.key}); final ShopStore store; final SupabaseClient? client; final Future<void> Function() onSignOut;
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  late final name = TextEditingController(text: widget.store.shopName), address = TextEditingController(text: widget.store.address), phone = TextEditingController(text: widget.store.phone), gstin = TextEditingController(text: widget.store.gstin), upi = TextEditingController(text: widget.store.upiId);
  Future<void> backup() async => perform(context, () async { await FilePicker.platform.saveFile(dialogTitle: 'Export shop backup', fileName: 'shopos-backup.json', type: FileType.custom, allowedExtensions: ['json'], bytes: Uint8List.fromList(utf8.encode(widget.store.backup()))); });
  Future<void> restore() async => perform(context, () async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (picked?.files.single.bytes == null) return;
    await widget.store.restoreBackup(utf8.decode(picked!.files.single.bytes!));
    name.text = widget.store.shopName ?? ''; address.text = widget.store.address; phone.text = widget.store.phone; gstin.text = widget.store.gstin; upi.text = widget.store.upiId;
  });
  @override Widget build(BuildContext context) { final store = widget.store; return ListView(padding: const EdgeInsets.all(20), children: [
    Text('Make it your shop', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 10), Text(store.demo ? 'Local demo · records are saved on this device.' : '${store.role.name} · ${store.plan} plan'), const SizedBox(height: 24),
    if (can(store.role, ShopPermission.manageSettings)) ...[
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Shop name')), const SizedBox(height: 16), TextField(controller: address, decoration: const InputDecoration(labelText: 'Shop address')), const SizedBox(height: 16), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')), const SizedBox(height: 16), TextField(controller: gstin, decoration: const InputDecoration(labelText: 'GSTIN (optional)')), const SizedBox(height: 16), TextField(controller: upi, decoration: const InputDecoration(labelText: 'UPI ID')), const SizedBox(height: 20),
      FilledButton.icon(onPressed: () => perform(context, () async { await store.saveSettings({'name': name.text, 'address': address.text, 'phone': phone.text, 'gstin': gstin.text.toUpperCase(), 'upi_id': upi.text}); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop details saved.'))); }), icon: const Icon(Icons.check), label: const Text('Save shop details')),
      const SizedBox(height: 24), DropdownButtonFormField<String>(initialValue: store.theme, decoration: const InputDecoration(labelText: 'Appearance'), items: const [DropdownMenuItem(value: 'system', child: Text('System')), DropdownMenuItem(value: 'light', child: Text('Light')), DropdownMenuItem(value: 'dark', child: Text('Dark'))], onChanged: (value) => perform(context, () => store.saveSettings({'theme': value}))), const SizedBox(height: 16),
      DropdownButtonFormField<String>(initialValue: store.paper, decoration: const InputDecoration(labelText: 'Invoice paper'), items: const [DropdownMenuItem(value: 'a4', child: Text('A4')), DropdownMenuItem(value: 'roll58', child: Text('58 mm receipt')), DropdownMenuItem(value: 'roll80', child: Text('80 mm receipt'))], onChanged: (value) => perform(context, () => store.saveSettings({'paper': value}))),
      SwitchListTile(contentPadding: EdgeInsets.zero, value: store.largeText, title: const Text('Larger text'), onChanged: (value) => perform(context, () => store.saveSettings({'large_text': value}))),
    ],
    const SizedBox(height: 24), OutlinedButton.icon(onPressed: backup, icon: const Icon(Icons.download), label: const Text('Export backup')), if (store.demo) OutlinedButton.icon(onPressed: restore, icon: const Icon(Icons.upload_file), label: const Text('Restore local demo backup')),
    const SizedBox(height: 24), TextButton.icon(onPressed: () => perform(context, () async { if (await confirm(context, 'Sign out?', 'Your saved shop records remain on this device.')) await widget.onSignOut(); }), icon: const Icon(Icons.logout), label: const Text('Sign out')),
  ]); }
  @override void dispose() { for (final controller in [name, address, phone, gstin, upi]) { controller.dispose(); } super.dispose(); }
}

class StaffPage extends StatefulWidget {
  const StaffPage({required this.store, this.client, super.key}); final ShopStore store; final SupabaseClient? client;
  @override State<StaffPage> createState() => _StaffPageState();
}
class _StaffPageState extends State<StaffPage> {
  List<Map<String, dynamic>> members = []; String? error; bool loading = false;
  @override void initState() { super.initState(); if (widget.client != null) load(); }
  Future<void> load() async { setState(() { loading = true; error = null; }); try { final rows = await widget.client!.from('memberships').select('user_id,role,is_active').eq('tenant_id', widget.store.tenantId); if (mounted) setState(() => members = rows); } catch (e) { if (mounted) setState(() => error = e.toString()); } finally { if (mounted) setState(() => loading = false); } }
  Future<void> edit([Map<String, dynamic>? member]) async {
    final values = await editRecord(context, title: member == null ? 'Add staff member' : 'Edit staff access', entity: 'staff', initial: member, fields: const [{'name': 'user_id', 'type': 'text', 'label': 'Registered user ID', 'required': true}, {'name': 'role', 'type': 'select', 'label': 'Role', 'options': ['owner','manager','cashier','viewer'], 'default': 'cashier'}, {'name': 'is_active', 'type': 'bool', 'label': 'Active', 'default': true}]);
    if (values != null && mounted) await perform(context, () async { await widget.client!.rpc('manage_staff', params: {'p_user_id': values['user_id'], 'p_role': values['role'], 'p_active': values['is_active']}); await load(); });
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Staff')), body: widget.client == null ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Staff management is available after signing in to your cloud shop.'))) : ListView(padding: const EdgeInsets.all(20), children: [const Text('Staff must already have a registered ShopOS account.'), const SizedBox(height: 16), FilledButton.icon(onPressed: loading ? null : () => edit(), icon: const Icon(Icons.person_add), label: const Text('Add registered staff')), if (loading) const LinearProgressIndicator(), if (error != null) Text(error!), ...members.map((member) => Card(child: ListTile(title: Text('${member['user_id']}'), subtitle: Text('${member['role']} · ${member['is_active'] == true ? 'Active' : 'Inactive'}'), trailing: const Icon(Icons.edit_outlined), onTap: () => edit(member))))]));
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({required this.store, this.client, super.key}); final ShopStore store; final SupabaseClient? client;
  @override State<SubscriptionPage> createState() => _SubscriptionPageState();
}
class _SubscriptionPageState extends State<SubscriptionPage> {
  bool busy = false;
  Future<void> checkout(String plan) async {
    setState(() => busy = true);
    await perform(context, () async { final response = await widget.client!.functions.invoke('create-subscription', body: {'plan': plan, 'billing_cycle': 'monthly'}); final url = response.data['checkout_url']; if (url == null || !await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) throw StateError('Could not open the payment checkout.'); });
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Subscription')), body: ListView(padding: const EdgeInsets.all(24), children: [Text('Current plan: ${widget.store.plan.toUpperCase()}', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16), Text(widget.store.demo ? 'Cloud subscriptions are available after signing in to your shop.' : 'Choose a plan to open the provider’s checkout. Your plan updates after payment confirmation.'), const SizedBox(height: 24), if (widget.client != null && widget.store.role == ShopRole.owner) ...['basic','standard','pro'].map((plan) => Card(child: ListTile(title: Text(plan.toUpperCase()), trailing: FilledButton(onPressed: busy ? null : () => checkout(plan), child: const Text('Open checkout'))))) ]));
}

List<List<String>> parseCsv(String source) {
  final rows = <List<String>>[], row = <String>[]; var cell = StringBuffer(), quoted = false;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (char == '"') { if (quoted && index + 1 < source.length && source[index + 1] == '"') { cell.write('"'); index++; } else { quoted = !quoted; } }
    else if (char == ',' && !quoted) { row.add(cell.toString().trim()); cell = StringBuffer(); }
    else if (char == '\n' && !quoted) { row.add(cell.toString().trim()); rows.add(List.of(row)); row.clear(); cell = StringBuffer(); }
    else if (char != '\r') { cell.write(char); }
  }
  if (quoted) throw const FormatException('Unclosed quotation mark in CSV');
  row.add(cell.toString().trim()); if (row.any((value) => value.isNotEmpty)) rows.add(row);
  return rows;
}
class CsvImportPage extends StatefulWidget {
  const CsvImportPage({required this.store, super.key}); final ShopStore store;
  @override State<CsvImportPage> createState() => _CsvImportPageState();
}
class _CsvImportPageState extends State<CsvImportPage> {
  final source = TextEditingController(); bool busy = false; String? message;
  Future<void> import() async {
    setState(() { busy = true; message = null; }); var count = 0;
    try {
      final rows = parseCsv(source.text.replaceFirst('\uFEFF', ''));
      if (rows.length < 2) throw const FormatException('Include a header and at least one product.');
      final headers = rows.first.map((name) => name.toLowerCase()).toList();
      if (!['name','price','stock'].every(headers.contains)) throw const FormatException('Required columns: name, price, stock');
      final values = <Map<String, dynamic>>[];
      for (final row in rows.skip(1).where((row) => row.any((cell) => cell.isNotEmpty))) {
        if (row.length != headers.length) throw const FormatException('Every row must match the header columns.');
        final product = Map<String, dynamic>.fromIterables(headers, row);
        for (final field in ['price','cost','stock','gst_rate','min_stock']) { if (product[field] != null && '${product[field]}'.isNotEmpty) product[field] = double.parse(product[field]); }
        final price = number(product['price']), stock = number(product['stock']);
        if ('${product['name']}'.trim().isEmpty || !price.isFinite || price < 0 || !stock.isFinite || stock < 0 || stock % 1 != 0) throw const FormatException('Check product names, prices, and whole stock quantities.');
        values.add(product);
      }
      for (final product in values) { await widget.store.saveProduct(product); count++; }
      if (mounted) setState(() => message = '$count products imported.');
    } catch (error) { if (mounted) setState(() => message = '$count products imported. $error'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Import products')), body: ListView(padding: const EdgeInsets.all(24), children: [const Text('CSV columns: name,price,stock,cost,gst_rate,category,barcode,min_stock\nRequired: name,price,stock'), const SizedBox(height: 20), OutlinedButton.icon(onPressed: busy ? null : () async { final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true); if (file?.files.single.bytes != null) source.text = utf8.decode(file!.files.single.bytes!); }, icon: const Icon(Icons.upload_file), label: const Text('Choose CSV')), const SizedBox(height: 16), TextField(controller: source, maxLines: 10, decoration: const InputDecoration(labelText: 'Or paste CSV')), const SizedBox(height: 16), if (message != null) Text(message!), FilledButton(onPressed: busy ? null : import, child: Text(busy ? 'Importing…' : 'Import products'))]));
  @override void dispose() { source.dispose(); super.dispose(); }
}
