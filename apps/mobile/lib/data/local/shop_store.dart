import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/services/invoice_number.dart';
import '../../core/services/permissions.dart';
import '../../domain/shop_models.dart';
import '../sync/drift_outbox.dart';
import 'shop_database.dart';

const productFields = <Map<String, dynamic>>[
  {'name':'name','type':'text','label':'Product name','required':true},
  {'name':'price','type':'decimal','label':'Selling price (before GST)','required':true,'min':0},
  {'name':'cost','type':'decimal','label':'Cost price','min':0,'default':0},
  {'name':'stock','type':'number','label':'Stock','min':0,'default':0},
  {'name':'gst_rate','type':'select','label':'GST %','options':['0','5','12','18','28'],'default':'0'},
  {'name':'barcode','type':'barcode','label':'Barcode'},
  {'name':'category','type':'text','label':'Category','default':'General'},
  {'name':'min_stock','type':'number','label':'Low stock threshold','default':5,'min':0},
];
const customerFields = <Map<String,dynamic>>[
  {'name':'name','type':'text','label':'Customer name','required':true},
  {'name':'phone','type':'text','label':'Mobile number','pattern':r'^(\+91)?[6-9]\d{9}$'},
  {'name':'address','type':'textarea','label':'Address'},
];

class ShopStore extends ChangeNotifier {
  ShopStore({this.database, String? tenantId, this.userId, this.role = ShopRole.owner, this.demo = true})
      : tenantId = tenantId ?? 'local-demo';
  final ShopDatabase? database;
  final String tenantId;
  final String? userId;
  ShopRole role;
  final bool demo;
  String? shopName;
  String templateKey = 'retail_basic', plan = 'free', address = '', gstin = '', upiId = '', phone = '';
  String devicePrefix = newId().replaceAll('-', '').substring(0, 12).toUpperCase();
  String locale = 'en', theme = 'system', paper = 'a4';
  bool largeText = false;
  DateTime trialEndsAt = DateTime.now().add(const Duration(days: 14));
  final List<Product> products = [];
  final List<Customer> customers = [];
  final List<Invoice> invoices = [];
  final List<CartLine> cart = [];
  final List<QueuedMutation> outbox = [];
  final Map<String, List<Map<String,dynamic>>> records = {};
  final Map<String, Map<String,dynamic>> schemas = {
    'product': {'label':'Product', 'fields': productFields},
    'customer': {'label':'Customer', 'fields': customerFields},
  };
  int _invoiceSequence = 0;
  Future<void> _tail = Future.value();
  DriftOutboxStore? get persistentOutbox => database == null ? null : DriftOutboxStore(database!, tenantId: tenantId);
  bool get isOnboarded => shopName != null;
  double get cartSubtotal => money(cart.fold<double>(0, (sum, item) => sum + item.total));
  int get lowStockCount => products.where((item) => item.isLowStock).length;
  double get todaySales => money(invoices.where((item) => _sameDay(item.createdAt, DateTime.now())).fold<double>(0, (sum,item)=>sum+item.total));
  double get totalOutstanding => money(customers.fold<double>(0, (sum,item)=>sum+item.outstanding));

  Future<void> initialize() async {
    if (database != null) {
      final rows = await (database!.select(database!.localRecords)..where((row)=>row.id.equals('state:$tenantId'))).get();
      if (rows.isNotEmpty) _restore(Map<String,dynamic>.from(jsonDecode(rows.first.data)));
      await refreshOutbox();
    }
    notifyListeners();
  }

  Future<void> refreshOutbox() async {
    if (persistentOutbox != null) { outbox..clear()..addAll(await persistentOutbox!.all()); }
    notifyListeners();
  }

  Future<void> createShop(String name, String template, {bool sampleData = false, String? shopAddress, String? shopGstin, String? shopPhone}) async {
    if (name.trim().isEmpty) throw ArgumentError('Enter the shop name');
    Map<String,dynamic>? templateData;
    try { templateData = Map<String,dynamic>.from(jsonDecode(await rootBundle.loadString('../../packages/supabase/seed/$template.json'))); }
    catch (_) { if (template != 'retail_basic') throw StateError('Template unavailable: $template'); }
    await _change((queued) {
      shopName = name.trim(); templateKey = template; address = shopAddress ?? ''; gstin = shopGstin ?? ''; phone = shopPhone ?? '';
      if (templateData != null) {
        for (final entity in templateData['entities'] as List) {
          schemas[entity['name']] = {...Map<String,dynamic>.from(entity['schema']), 'label': entity['label']};
        }
      }
      if (sampleData && demo && products.isEmpty) {
        for (final data in [
          {'name':'Premium Rice 1 kg','price':72,'cost':58,'stock':18,'gst_rate':5},
          {'name':'Sunflower Oil 1 L','price':145,'cost':126,'stock':4,'gst_rate':5},
          {'name':'Bath Soap','price':35,'cost':25,'stock':24,'gst_rate':18},
        ]) {
          final product = Product.fromJson({'id':newId(),...data}); products.add(product);
          queued.add(_mutation('product','create', product.toJson()));
        }
      }
    });
  }

  Future<void> saveProduct(Map<String,dynamic> values, {String? id}) => _change((queued) {
    _require(ShopPermission.manageProducts);
    final product = Product.fromJson({...values, 'id': id ?? newId()});
    if (product.name.trim().isEmpty || !product.price.isFinite || product.price < 0 || product.cost < 0 || product.stock < 0 ||
        !product.gst.isFinite || product.gst < 0 || product.gst > 100 || number(values['stock']) % 1 != 0) throw ArgumentError('Enter a name and valid non-negative prices, whole stock, and GST');
    if (product.barcode?.isNotEmpty == true && products.any((p)=>p.id != product.id && p.barcode == product.barcode)) throw ArgumentError('Barcode already exists');
    if (id == null && plan == 'free' && products.length >= 50 && DateTime.now().isAfter(trialEndsAt)) throw StateError('Free plan allows 50 products');
    final index = products.indexWhere((p)=>p.id==product.id);
    final old = index < 0 ? null : products[index];
    if (index < 0) { products.add(product); } else { products[index]=product; }
    queued.add(_mutation('product', index<0?'create':'update', product.toJson()));
    if (old != null && old.stock != product.stock) _addRecord('stock_adjustment', {'product_id':product.id,'delta':product.stock-old.stock,'reason':'Manual adjustment'}, queued);
  });
  Future<void> addProduct(Map<String,dynamic> values) => saveProduct(values);

  Future<void> deleteProduct(Product product) => _change((queued) {
    _require(ShopPermission.manageProducts);
    if(cart.any((line)=>line.product.id==product.id)) throw StateError('Remove the product from the current bill first');
    products.removeWhere((item)=>item.id==product.id); queued.add(_mutation('product','delete', {'id':product.id}));
  });

  Future<void> addCustomer(String name, String phone) => saveCustomer({'name':name,'phone':phone});
  Future<void> saveCustomer(Map<String,dynamic> data, {String? id}) => _change((queued) {
    _require(ShopPermission.createInvoice);
    if ('${data['name']??''}'.trim().isEmpty) throw ArgumentError('Customer name is required');
    final index = customers.indexWhere((item)=>item.id==id);
    final customer = Customer.fromJson({...data, 'id':id??newId(), 'outstanding':index<0?0:customers[index].outstanding});
    if(index<0) { customers.add(customer); } else { customers[index]=customer; }
    queued.add(_mutation('customer',index<0?'create':'update',customer.toJson()));
  });

  void addToCart(Product product) {
    _require(ShopPermission.createInvoice);
    final index = cart.indexWhere((line)=>line.product.id==product.id);
    final quantity = index<0?1:cart[index].quantity+1;
    if(quantity>product.stock) throw StateError('Only ${product.stock} units are available');
    if(index<0) { cart.add(CartLine(product:product,quantity:1)); } else { cart[index]=cart[index].copyWith(quantity:quantity); }
    notifyListeners();
  }
  void setCartQuantity(String id, int quantity) {
    _require(ShopPermission.createInvoice);
    final index = cart.indexWhere((line)=>line.product.id==id); if(index<0)return;
    if(quantity>products.firstWhere((item)=>item.id==id).stock) throw StateError('Quantity exceeds available stock');
    if(quantity<=0) { cart.removeAt(index); } else { cart[index]=cart[index].copyWith(quantity:quantity); }
    notifyListeners();
  }
  void setLineDiscount(String id, double percent, double flat, double gst) {
    final index=cart.indexWhere((line)=>line.product.id==id); if(index<0)return;
    if(!percent.isFinite||!flat.isFinite||!gst.isFinite||percent<0||percent>100||flat<0||gst<0||gst>100) throw ArgumentError('Invalid discount or GST');
    final line=cart[index].copyWith(discountPercent:percent,discountFlat:flat,taxOverride:gst);
    if(line.total<0) throw ArgumentError('Discount exceeds line amount');
    cart[index]=line; notifyListeners();
  }

  Future<Invoice> checkout({required String paymentMode, Customer? customer, double discount = 0, double discountPercent = 0, bool paymentConfirmed = false}) async {
    late Invoice invoice;
    await _change((queued) {
      _require(ShopPermission.createInvoice);
      if(cart.isEmpty) throw StateError('Cart is empty');
      if(!['cash','upi','card','credit'].contains(paymentMode)) throw ArgumentError('Invalid payment method');
      if(['upi','card'].contains(paymentMode)&&!paymentConfirmed) throw StateError('Confirm receipt of payment before saving');
      if(paymentMode=='credit' && (customer==null || !customers.any((item)=>item.id==customer.id))) throw StateError('Select a customer for credit');
      for(final line in cart) {
        final current=products.firstWhere((item)=>item.id==line.product.id);
        if(line.quantity<1||line.quantity>current.stock) throw StateError('Insufficient stock for ${current.name}');
      }
      if(plan=='free'&&DateTime.now().isAfter(trialEndsAt)&&invoices.where((i)=>i.createdAt.year==DateTime.now().year&&i.createdAt.month==DateTime.now().month).length>=100) throw StateError('Free plan allows 100 invoices per month');
      final totals=BillTotals(cart,discount:discount,percent:discountPercent);
      invoice=Invoice(id:newId(),number:nextInvoiceNumber(devicePrefix:devicePrefix,now:DateTime.now(),sequence:++_invoiceSequence),
        createdAt:DateTime.now(),lines:List.of(cart),total:totals.total,paymentMode:paymentMode,customerId:customer?.id,
        customerName:customer?.name,discount:totals.billDiscount,tax:totals.tax,createdBy:userId);
      invoices.insert(0,invoice);
      queued.add(_mutation('invoice','create',invoice.toJson()));
      for(final line in cart) {
        final index=products.indexWhere((item)=>item.id==line.product.id);
        products[index]=products[index].copyWith(stock:products[index].stock-line.quantity);
        queued.add(_mutation('product','adjust',{'id':line.product.id,'field':'stock','delta':-line.quantity}));
        if (role != ShopRole.cashier) _addRecord('stock_adjustment',{'product_id':line.product.id,'delta':-line.quantity,'reason':'Sale','invoice_id':invoice.id},queued);
      }
      if(paymentMode=='credit' && invoice.total > 0) {
        final index=customers.indexWhere((item)=>item.id==customer!.id);
        customers[index]=customers[index].copyWith(outstanding:money(customers[index].outstanding+invoice.total));
        queued.add(_mutation('customer','adjust',{'id':customer!.id,'field':'outstanding','delta':invoice.total}));
        _addRecord('ledger',{'customer_id':customer.id,'invoice_id':invoice.id,'amount':invoice.total,'type':'credit_sale'},queued);
      }
      cart.clear();
    });
    return invoice;
  }

  Future<void> receivePayment(Customer customer, double amount, {String mode='cash'}) => _change((queued) {
    _require(ShopPermission.createInvoice);
    final index=customers.indexWhere((item)=>item.id==customer.id);
    if(index<0||!amount.isFinite||amount<=0||money(amount)>customers[index].outstanding) throw ArgumentError('Payment must be within the outstanding balance');
    customers[index]=customers[index].copyWith(outstanding:money(customers[index].outstanding-money(amount)));
    queued.add(_mutation('customer','adjust',{'id':customer.id,'field':'outstanding','delta':-money(amount)}));
    _addRecord('ledger',{'customer_id':customer.id,'amount':money(amount),'type':'payment_received','payment_mode':mode},queued);
  });

  Future<void> saveEntity(String entity, Map<String,dynamic> data, {String? id}) => _change((queued) {
    _require(ShopPermission.manageProducts);
    if(['invoice','ledger','stock_adjustment','customer','product'].contains(entity)) throw ArgumentError('Use the dedicated flow for this entity');
    _addRecord(entity,{...data,if(id!=null)'id':id},queued);
  });

  Future<void> saveSettings(Map<String,dynamic> values) => _change((queued) {
    _require(ShopPermission.manageSettings);
    if('${values['name']??shopName}'.trim().isEmpty) throw ArgumentError('Shop name cannot be empty');
    shopName='${values['name']??shopName}'; address='${values['address']??address}'; gstin='${values['gstin']??gstin}';
    upiId='${values['upi_id']??upiId}'; phone='${values['phone']??phone}'; locale='${values['locale']??locale}';
    theme='${values['theme']??theme}'; largeText=values['large_text']??largeText; paper='${values['paper']??paper}';
    if(upiId.isNotEmpty&&!RegExp(r'^[\w.\-]+@[\w.\-]+$').hasMatch(upiId)) throw ArgumentError('Enter a valid UPI ID');
    if(!demo) queued.add(_mutation('_tenant','update',{'name':shopName,'address':{'text':address,'upi_id':upiId},'gstin':gstin,'phone':phone}));
  });

  Future<void> applyRemote(List<Map<String,dynamic>> rows, {Map<String,Map<String,dynamic>>? entitySchemas, Map<String,dynamic>? tenant}) => _change((_) {
    if(entitySchemas!=null) schemas.addAll(entitySchemas);
    if(tenant!=null) {
      shopName=tenant['name']; plan=tenant['plan']??'free'; trialEndsAt=DateTime.parse(tenant['trial_ends_at']);
      templateKey=tenant['template_key']??templateKey; phone=tenant['phone']??''; gstin=tenant['gstin']??'';
      final info=tenant['address']; if(info is Map) {address='${info['text']??''}'; upiId='${info['upi_id']??''}';}
    }
    for(final row in rows) {
      final entity='${row['entity']}'; final id='${row['id']}'; final deleted=row['deleted_at']!=null;
      final data={...Map<String,dynamic>.from(row['data']??{}),'id':id};
      switch(entity) {
        case 'product': products.removeWhere((item)=>item.id==id); if(!deleted) products.add(Product.fromJson(data));
        case 'customer': customers.removeWhere((item)=>item.id==id); if(!deleted) customers.add(Customer.fromJson(data));
        case 'invoice': invoices.removeWhere((item)=>item.id==id); if(!deleted) invoices.add(Invoice.fromJson(data));
        default: final list=records.putIfAbsent(entity,()=>[]); list.removeWhere((item)=>item['id']==id); if(!deleted) list.add(data);
      }
    }
    invoices.sort((a,b)=>b.createdAt.compareTo(a.createdAt));
  }, enqueue:false);

  String backup() => jsonEncode({'version':1,'tenant_id':tenantId,'state':_snapshot()});
  Future<void> restoreBackup(String source) async {
    final data=Map<String,dynamic>.from(jsonDecode(source));
    if(data['version']!=1||data['tenant_id']!=tenantId||data['state'] is! Map) throw ArgumentError('This backup belongs to another shop or format');
    if(!demo) throw StateError('Live backups are read-only exports. Restore on the server to avoid overwriting newer sales.');
    await _change((_)=>_restore(Map<String,dynamic>.from(data['state'])),enqueue:false);
  }

  Future<void> wipeLocal() async {
    if(database!=null) await database!.transaction(() async {
      await (database!.delete(database!.localRecords)..where((row)=>row.tenantId.equals(tenantId))).go();
      for(final mutation in await persistentOutbox!.all()) {await persistentOutbox!.remove(mutation.id);}
    });
    shopName=null; products.clear(); customers.clear(); invoices.clear(); cart.clear(); outbox.clear(); records.clear(); notifyListeners();
  }

  void _require(ShopPermission permission) { if(!can(role,permission)) throw StateError('Your role does not allow this action'); }
  QueuedMutation _mutation(String entity,String action,Map<String,dynamic> payload)=>QueuedMutation(id:newId(),entity:entity,action:action,payload:{...payload,'updated_at':DateTime.now().toUtc().toIso8601String()},createdAt:DateTime.now());
  void _addRecord(String entity,Map<String,dynamic> data,List<QueuedMutation> queued) {
    final record={...data,'id':data['id']??newId(),'created_at':data['created_at']??DateTime.now().toUtc().toIso8601String()};
    final list=records.putIfAbsent(entity,()=>[]); final exists=list.any((item)=>item['id']==record['id']);
    list.removeWhere((item)=>item['id']==record['id']); list.add(record);
    queued.add(_mutation(entity,exists?'update':'create',record));
  }
  Future<void> _change(void Function(List<QueuedMutation>) action,{bool enqueue=true}) {
    final operation=_tail.then((_) async {
      final before=jsonEncode(_snapshot()); final previousCart=List<CartLine>.of(cart); final queued=<QueuedMutation>[];
      try {
        action(queued);
        final mutation=queued.isEmpty||!enqueue?null:QueuedMutation(id:newId(),entity:'_batch',action:'create',payload:{'_tenant_id':tenantId,'mutations':queued.map((item)=>item.toJson()).toList()},createdAt:DateTime.now());
        if(database!=null) await database!.transaction(() async {
          await database!.saveRecord(id:'state:$tenantId',tenantId:tenantId,entity:'_state',data:_snapshot(),createdAt:DateTime.now(),updatedAt:DateTime.now());
          if(mutation!=null) await persistentOutbox!.add(mutation);
        });
        if(mutation!=null) outbox.add(mutation);
      } catch (_) { _restore(Map<String,dynamic>.from(jsonDecode(before))); cart..clear()..addAll(previousCart); rethrow; }
      notifyListeners();
    });
    _tail=operation.catchError((Object _){}); return operation;
  }
  Map<String,dynamic> _snapshot()=>{'name':shopName,'template':templateKey,'plan':plan,'trial':trialEndsAt.toIso8601String(),
    'address':address,'gstin':gstin,'upi_id':upiId,'phone':phone,'device':devicePrefix,'sequence':_invoiceSequence,
    'locale':locale,'theme':theme,'large_text':largeText,'paper':paper,
    'products':products.map((p)=>p.toJson()).toList(),'customers':customers.map((c)=>c.toJson()).toList(),
    'invoices':invoices.map((i)=>i.toJson()).toList(),'records':records,'schemas':schemas};
  void _restore(Map<String,dynamic> data) {
    shopName=data['name']; templateKey=data['template']??'retail_basic'; plan=data['plan']??'free';
    trialEndsAt=DateTime.tryParse('${data['trial']}')??trialEndsAt; devicePrefix=data['device']??devicePrefix;
    _invoiceSequence=data['sequence']??0; address=data['address']??''; gstin=data['gstin']??''; upiId=data['upi_id']??''; phone=data['phone']??'';
    locale=data['locale']??'en';theme=data['theme']??'system';largeText=data['large_text']??false;paper=data['paper']??'a4';
    products..clear()..addAll((data['products'] as List? ?? []).map((p)=>Product.fromJson(Map<String,dynamic>.from(p))));
    customers..clear()..addAll((data['customers'] as List? ?? []).map((c)=>Customer.fromJson(Map<String,dynamic>.from(c))));
    invoices..clear()..addAll((data['invoices'] as List? ?? []).map((i)=>Invoice.fromJson(Map<String,dynamic>.from(i))));
    records..clear()..addAll((data['records'] as Map? ?? {}).map((key,value)=>MapEntry('$key',(value as List).map((v)=>Map<String,dynamic>.from(v)).toList())));
    if(data['schemas'] is Map) schemas..clear()..addAll((data['schemas'] as Map).map((key,value)=>MapEntry('$key',Map<String,dynamic>.from(value))));
  }
  bool _sameDay(DateTime a,DateTime b)=>a.toLocal().year==b.year&&a.toLocal().month==b.month&&a.toLocal().day==b.day;
}
