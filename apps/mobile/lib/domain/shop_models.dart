import 'package:uuid/uuid.dart';

String newId() => const Uuid().v4();
double money(num value) => (value * 100).round() / 100;
double number(dynamic value, [double fallback = 0]) => parseNumber(value, fallback);
double parseNumber(dynamic value, [double fallback = 0]) => value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

class Product {
  const Product({required this.id, required this.name, required this.price, required this.stock,
    this.cost = 0, this.gst = 0, this.barcode, this.category = 'General', this.minStock = 5, this.extra = const {}});
  final String id, name, category;
  final double price, cost, gst;
  final int stock, minStock;
  final String? barcode;
  final Map<String, dynamic> extra;
  bool get isLowStock => stock <= minStock;
  Product copyWith({int? stock}) => Product.fromJson({...toJson(), 'stock': stock ?? this.stock});
  factory Product.fromJson(Map<String, dynamic> data) => Product(
    id: data['id'] as String, name: '${data['name'] ?? ''}', price: number(data['price']),
    stock: number(data['stock']).toInt(), cost: number(data['cost']), gst: number(data['gst_rate'] ?? data['gst']),
    barcode: (data['sku'] ?? data['barcode'])?.toString(), category: '${data['category'] ?? 'General'}',
    minStock: number(data['min_stock'] ?? data['low_stock_threshold'], 5).toInt(), extra: data);
  Map<String, dynamic> toJson() => {...extra, 'id': id, 'name': name, 'price': price, 'stock': stock, 'cost': cost,
    'gst_rate': gst, 'gst': gst, 'barcode': barcode, 'sku': barcode, 'category': category, 'min_stock': minStock, 'low_stock_threshold': minStock};
}

class Customer {
  const Customer({required this.id, required this.name, this.phone = '', this.outstanding = 0, this.extra = const {}});
  final String id, name, phone;
  final double outstanding;
  final Map<String, dynamic> extra;
  Customer copyWith({double? outstanding}) => Customer.fromJson({...toJson(), 'outstanding': outstanding ?? this.outstanding});
  factory Customer.fromJson(Map<String, dynamic> data) => Customer(id: data['id'] as String, name: '${data['name'] ?? ''}',
    phone: '${data['phone'] ?? ''}', outstanding: number(data['outstanding']), extra: data);
  Map<String, dynamic> toJson() => {...extra, 'id': id, 'name': name, 'phone': phone, 'outstanding': outstanding};
}

class CartLine {
  const CartLine({required this.product, required this.quantity, this.discountPercent = 0, this.discountFlat = 0, this.taxOverride});
  final Product product;
  final int quantity;
  final double discountPercent, discountFlat;
  final double? taxOverride;
  double get gross => money(product.price * quantity);
  double get discount => money(gross * discountPercent / 100 + discountFlat);
  double get total => money(gross - discount);
  double get taxRate => taxOverride ?? product.gst;
  CartLine copyWith({int? quantity, double? discountPercent, double? discountFlat, double? taxOverride}) => CartLine(
    product: product, quantity: quantity ?? this.quantity, discountPercent: discountPercent ?? this.discountPercent,
    discountFlat: discountFlat ?? this.discountFlat, taxOverride: taxOverride ?? this.taxOverride);
  Map<String, dynamic> toJson() => {'product': product.toJson(), 'quantity': quantity, 'discount_percent': discountPercent,
    'discount_flat': discountFlat, 'gst_rate': taxRate, 'total': total};
  factory CartLine.fromJson(Map<String, dynamic> data) => CartLine(product: Product.fromJson(Map<String, dynamic>.from(data['product'])),
    quantity: number(data['quantity']).toInt(), discountPercent: number(data['discount_percent']),
    discountFlat: number(data['discount_flat']), taxOverride: number(data['gst_rate']));
}

class BillTotals {
  BillTotals(List<CartLine> lines, {double discount = 0, double percent = 0}) {
    if (!discount.isFinite || !percent.isFinite || discount < 0 || percent < 0 || percent > 100) throw ArgumentError('Invalid bill discount');
    subtotal = money(lines.fold<double>(0, (sum, line) => sum + line.total));
    billDiscount = money(discount + subtotal * percent / 100);
    if (billDiscount > subtotal) throw ArgumentError('Discount exceeds the bill amount');
    taxable = money(subtotal - billDiscount);
    tax = money(lines.fold<double>(0, (sum, line) => sum + (subtotal == 0 ? 0 : line.total * taxable / subtotal * line.taxRate / 100)));
    total = money(taxable + tax);
  }
  late final double subtotal, billDiscount, taxable, tax, total;
}

class Invoice {
  const Invoice({required this.id, required this.number, required this.createdAt, required this.lines,
    required this.total, required this.paymentMode, this.customerId, this.customerName, this.discount = 0, this.tax = 0, this.createdBy});
  final String id, number, paymentMode;
  final String? customerId, customerName, createdBy;
  final DateTime createdAt;
  final List<CartLine> lines;
  final double total, discount, tax;
  double get subtotal => money(lines.fold<double>(0, (sum, line) => sum + line.total));
  double get profit => money(total - tax - lines.fold<double>(0, (sum, line) => sum + line.product.cost * line.quantity));
  Map<String, dynamic> toJson() => {'id': id, 'invoice_number': number, 'created_at': createdAt.toUtc().toIso8601String(),
    'invoice_date': createdAt.toUtc().toIso8601String(), 'items': lines.map((line) => line.toJson()).toList(), 'total': total,
    'payment_mode': paymentMode, 'payment_status': paymentMode == 'credit' ? 'pending' : 'paid', 'customer_id': customerId,
    'customer_name': customerName, 'discount_amount': discount, 'tax_amount': tax, 'subtotal': subtotal, 'created_by': createdBy};
  factory Invoice.fromJson(Map<String, dynamic> data) => Invoice(id: data['id'] as String, number: '${data['invoice_number']}',
    createdAt: DateTime.parse(data['created_at'] ?? data['invoice_date']),
    lines: (data['items'] as List? ?? []).map((line) => CartLine.fromJson(Map<String, dynamic>.from(line))).toList(),
    total: parseNumber(data['total']), paymentMode: '${data['payment_mode']}', customerId: data['customer_id'],
    customerName: data['customer_name'], discount: parseNumber(data['discount_amount']), tax: parseNumber(data['tax_amount']), createdBy: data['created_by']);
}

class QueuedMutation {
  const QueuedMutation({required this.id, required this.entity, required this.action, required this.payload,
    required this.createdAt, this.attempts = 0, this.nextAttemptAt});
  final String id, entity, action;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;
  Map<String, dynamic> toJson() => {'id': id, 'entity': entity, 'action': action, 'payload': payload};
}
