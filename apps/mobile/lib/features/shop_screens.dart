import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/invoice_pdf_service.dart';
import '../core/services/permissions.dart';
import '../data/local/shop_store.dart';
import '../data/remote/shop_session.dart';
import '../domain/shop_models.dart';
import '../lowcode/field_registry.dart';
import '../lowcode/form_renderer.dart';
import '../lowcode/field_types/code_field.dart';
import 'management_screens.dart';

String rupees(num value)=>'₹${value.toStringAsFixed(2)}';
void showError(BuildContext context,Object error){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString())));}
Future<void> perform(BuildContext context,Future<void> Function() action) async {try{await action();}catch(e){showError(context,e);}}

Future<Map<String,dynamic>?> editRecord(BuildContext context,{required String title,required String entity,required List fields,Map<String,dynamic>? initial,ShopStore? store}) {
  final schemas=fields.map((field){
    var schema=FieldSchema.fromJson(Map<String,dynamic>.from(field));
    if(schema.type=='relation'&&store!=null){
      final records=schema.target=='customer'?store.customers.map((c)=>c.toJson()).toList():schema.target=='product'?store.products.map((p)=>p.toJson()).toList():store.records[schema.target]??[];
      schema=schema.copyWith(config:{...schema.config,'records':records});
    }
    return schema;
  }).toList();
  return showDialog<Map<String,dynamic>>(context:context,builder:(dialog)=>Dialog(child:ConstrainedBox(
    constraints:const BoxConstraints(maxWidth:760,maxHeight:720),child:Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:Row(children:[Expanded(child:Text(title,style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:()=>Navigator.pop(dialog),icon:const Icon(Icons.close))])),
      Expanded(child:DynamicForm(entityId:entity,fields:schemas,initialData:initial,onSubmit:(data)=>Navigator.pop(dialog,data),onCancel:()=>Navigator.pop(dialog))),
    ]))));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.store,this.session,this.client,required this.onSignOut,super.key});
  final ShopStore store;final ShopSession? session;final SupabaseClient? client;final Future<void> Function() onSignOut;
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int selected=0;
  void open(Widget page)=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>AnimatedBuilder(animation:widget.store,builder:(_,__)=>page)));
  @override Widget build(BuildContext context){
    final store=widget.store;
    final pages=[DashboardPage(store:store,onSell:()=>setState(()=>selected=2),client:widget.client),ProductsPage(store:store),BillingPage(store:store),CustomersPage(store:store,client:widget.client),SettingsPage(store:store,client:widget.client,onSignOut:widget.onSignOut)];
    return Scaffold(appBar:AppBar(title:Text(store.shopName??'ShopOS'),actions:[
      StreamBuilder(stream:widget.session?.engine?.statusStream,builder:(context,snapshot){
        final state=widget.session?.engine?.currentStatus;
        return TextButton.icon(onPressed:()=>perform(context,()async{
          if(widget.session==null){showError(context,'Local demo: cloud sync is not configured. Data remains on this device.');return;}
          await widget.session!.engine!.syncNow();await store.refreshOutbox();
          if(widget.session!.engine!.currentStatus.errorMessage!=null)showError(context,widget.session!.engine!.currentStatus.errorMessage!);
        }),icon:Icon(state?.state.name=='synced'?Icons.cloud_done:Icons.cloud_sync),label:Text(store.demo?'Local demo':'${store.outbox.length} pending'));
      }),
    ]),drawer:Drawer(child:SafeArea(child:ListView(children:[
      ListTile(title:Text(store.shopName??'ShopOS'),subtitle:Text('${store.role.name} • ${store.plan}')),
      if(can(store.role,ShopPermission.viewReports))ListTile(leading:const Icon(Icons.analytics),title:const Text('Reports'),onTap:(){Navigator.pop(context);open(ReportsPage(store:store));}),
      ListTile(leading:const Icon(Icons.receipt_long),title:const Text('Invoices'),onTap:(){Navigator.pop(context);open(InvoicesPage(store:store,client:widget.client));}),
      if(can(store.role,ShopPermission.manageProducts))ListTile(leading:const Icon(Icons.view_module),title:const Text('Shop modules'),onTap:(){Navigator.pop(context);open(ModulesPage(store:store));}),
      if(can(store.role,ShopPermission.manageStaff))ListTile(leading:const Icon(Icons.group),title:const Text('Staff'),onTap:(){Navigator.pop(context);open(StaffPage(store:store,client:widget.client));}),
      ListTile(leading:const Icon(Icons.workspace_premium),title:const Text('Subscription'),onTap:(){Navigator.pop(context);open(SubscriptionPage(store:store,client:widget.client));}),
    ]))),body:IndexedStack(index:selected,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:selected,onDestinationSelected:(index)=>setState(()=>selected=index),destinations:const[
      NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Home'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'Products'),
      NavigationDestination(icon:Icon(Icons.point_of_sale),label:'Sell'),NavigationDestination(icon:Icon(Icons.people_outline),label:'Customers'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Settings'),
    ]));
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.store,required this.onSell,this.client,super.key});
  final ShopStore store;final VoidCallback onSell;final SupabaseClient? client;
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Your shop at a glance',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:16),
    if(DateTime.now().isBefore(store.trialEndsAt))Card(child:ListTile(leading:const Icon(Icons.timer_outlined),title:Text('${store.trialEndsAt.difference(DateTime.now()).inDays+1} days left in your trial'))),
    if(can(store.role,ShopPermission.viewReports))...[
      MetricCard(label:'Today’s sales',value:rupees(store.todaySales),icon:Icons.trending_up),
      MetricCard(label:'Customer outstanding',value:rupees(store.totalOutstanding),icon:Icons.account_balance_wallet),
    ],
    MetricCard(label:'Low stock',value:'${store.lowStockCount} products',icon:Icons.warning_amber),const SizedBox(height:16),
    if(can(store.role,ShopPermission.createInvoice))FilledButton.icon(onPressed:onSell,icon:const Icon(Icons.add_shopping_cart),label:const Text('Create a bill')),
    const SizedBox(height:20),Text('Recent bills',style:Theme.of(context).textTheme.titleLarge),
    if(store.invoices.isEmpty)const ListTile(title:Text('No bills yet. Add products, then create your first sale.')),
    ...store.invoices.take(5).map((invoice)=>ListTile(title:Text(invoice.number),subtitle:Text(invoice.paymentMode.toUpperCase()),trailing:Text(rupees(invoice.total)),onTap:()=>openInvoice(context,store,invoice,client:client))),
  ]);
}
class MetricCard extends StatelessWidget {
  const MetricCard({required this.label,required this.value,required this.icon,super.key});
  final String label,value;final IconData icon;
  @override Widget build(BuildContext context)=>Card(child:ListTile(leading:Icon(icon),title:Text(label),subtitle:Text(value,style:Theme.of(context).textTheme.titleLarge)));
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({required this.store,super.key});final ShopStore store;
  @override State<ProductsPage> createState()=>_ProductsPageState();
}
class _ProductsPageState extends State<ProductsPage> {
  String query='',sort='name';bool lowOnly=false;
  Future<void> edit([Product? product]) async {
    final store=widget.store;
    final data=await editRecord(context,title:product==null?'Add product':'Edit product',entity:'product',fields:store.schemas['product']?['fields']??productFields,initial:product?.toJson(),store:store);
    if(data!=null&&mounted)await perform(context,()=>store.saveProduct(data,id:product?.id));
  }
  @override Widget build(BuildContext context){
    final store=widget.store;
    final products=store.products.where((p)=>'${p.name} ${p.barcode??''} ${p.category}'.toLowerCase().contains(query.toLowerCase())&&(!lowOnly||p.isLowStock)).toList()
      ..sort((a,b)=>sort=='price'?a.price.compareTo(b.price):sort=='stock'?a.stock.compareTo(b.stock):a.name.compareTo(b.name));
    return ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[Expanded(child:Text('Products',style:Theme.of(context).textTheme.headlineSmall)),if(can(store.role,ShopPermission.manageProducts))...[
        IconButton(tooltip:'Import CSV',onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>CsvImportPage(store:store))),icon:const Icon(Icons.upload_file)),
        FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('Add product')),
      ]]),const SizedBox(height:12),TextField(decoration:InputDecoration(labelText:'Search name, category or barcode',suffixIcon:IconButton(icon:const Icon(Icons.qr_code_scanner),onPressed:()async{final code=await scanCode(context);if(code!=null&&mounted)setState(()=>query=code);})),onChanged:(v)=>setState(()=>query=v)),
      Wrap(spacing:12,crossAxisAlignment:WrapCrossAlignment.center,children:[FilterChip(label:const Text('Low stock'),selected:lowOnly,onSelected:(v)=>setState(()=>lowOnly=v)),DropdownButton<String>(value:sort,items:const[DropdownMenuItem(value:'name',child:Text('Name')),DropdownMenuItem(value:'price',child:Text('Price')),DropdownMenuItem(value:'stock',child:Text('Stock'))],onChanged:(v)=>setState(()=>sort=v!))]),
      if(products.isEmpty)const ListTile(title:Text('No products found')),
      ...products.map((p)=>Card(child:ListTile(leading:Icon(p.isLowStock?Icons.warning_amber:Icons.inventory_2_outlined),title:Text(p.name),subtitle:Text('${p.category} • ${p.stock} in stock • GST ${p.gst}%'),
        onTap:can(store.role,ShopPermission.manageProducts)?()=>edit(p):null,trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(rupees(p.price)),if(can(store.role,ShopPermission.manageProducts))PopupMenuButton<String>(onSelected:(choice)async{
          if(choice=='history'){showDialog<void>(context:context,builder:(_)=>AlertDialog(title:Text(p.name),content:SizedBox(width:400,child:ListView(shrinkWrap:true,children:(store.records['stock_adjustment']??[]).where((r)=>r['product_id']==p.id).map((r)=>ListTile(title:Text('${r['delta']} • ${r['reason']}'),subtitle:Text('${r['created_at']}'))).toList()))));}
          if(choice=='delete'){final confirmed=await confirm(context,'Delete ${p.name}?','Previously saved invoices keep their original items.');if(confirmed&&mounted)await perform(context,()=>store.deleteProduct(p));}
        },itemBuilder:(_)=>const[PopupMenuItem(value:'history',child:Text('Stock history')),PopupMenuItem(value:'delete',child:Text('Delete'))])])))),
    ]);
  }
}

class BillingPage extends StatefulWidget {
  const BillingPage({required this.store,super.key});final ShopStore store;
  @override State<BillingPage> createState()=>_BillingPageState();
}
class _BillingPageState extends State<BillingPage> {
  String query='',mode='cash';String? customerId;bool confirmed=false,saving=false;
  final discount=TextEditingController(text:'0'),percent=TextEditingController(text:'0');
  Future<void> save()async {
    if(saving)return;setState(()=>saving=true);
    try{
      final customer=widget.store.customers.where((c)=>c.id==customerId).firstOrNull;
      final invoice=await widget.store.checkout(paymentMode:mode,customer:customer,discount:double.parse(discount.text),discountPercent:double.parse(percent.text),paymentConfirmed:confirmed);
      if(mounted){discount.text='0';percent.text='0';setState(()=>confirmed=false);await openInvoice(context,widget.store,invoice);}
    }catch(e){if(mounted)showError(context,e);}finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context){
    final store=widget.store;
    if(!can(store.role,ShopPermission.createInvoice))return const Center(child:Text('Your role cannot create bills.'));
    BillTotals? totals;String? totalError;
    try{totals=BillTotals(store.cart,discount:double.parse(discount.text),percent:double.parse(percent.text));}catch(e){totalError=e.toString();}
    return ListView(padding:const EdgeInsets.all(16),children:[
      Text('New bill',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),
      TextField(onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(labelText:'Search products',suffixIcon:IconButton(icon:const Icon(Icons.qr_code_scanner),onPressed:()async{
        final code=await scanCode(context);if(code==null||!mounted)return;
        final found=store.products.where((p)=>p.barcode==code).firstOrNull;
        if(found==null){showError(context,'No product matches $code');}else{try{store.addToCart(found);}catch(e){showError(context,e);}}
      }))),
      ...store.products.where((p)=>'${p.name} ${p.category} ${p.barcode??''}'.toLowerCase().contains(query.toLowerCase())).take(30).map((p)=>ListTile(title:Text(p.name),subtitle:Text('${rupees(p.price)} • ${p.stock} available'),trailing:IconButton(tooltip:'Add to bill',icon:const Icon(Icons.add_circle),onPressed:p.stock<=0?null:(){try{store.addToCart(p);}catch(e){showError(context,e);}}))),
      const Divider(),if(store.cart.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('Tap + to add products to this bill.')),
      ...store.cart.map((line)=>Card(child:Column(children:[ListTile(title:Text(line.product.name),subtitle:Text('${rupees(line.total)} before GST'),trailing:TextButton(onPressed:()async{
        final data=await editRecord(context,title:'Item discount and GST',entity:'cart',initial:{'percent':line.discountPercent,'flat':line.discountFlat,'gst':line.taxRate},fields:const[
          {'name':'percent','type':'decimal','label':'Discount %','min':0,'max':100},{'name':'flat','type':'decimal','label':'Flat discount','min':0},{'name':'gst','type':'decimal','label':'GST %','min':0,'max':100}]);
        if(data!=null){try{store.setLineDiscount(line.product.id,number(data['percent']),number(data['flat']),number(data['gst']));}catch(e){if(mounted)showError(context,e);}}
      },child:const Text('Discount / tax'))),Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(tooltip:'Decrease quantity',icon:const Icon(Icons.remove_circle_outline),onPressed:()=>store.setCartQuantity(line.product.id,line.quantity-1)),
        Text('${line.quantity}',style:Theme.of(context).textTheme.titleLarge),IconButton(tooltip:'Increase quantity',icon:const Icon(Icons.add_circle_outline),onPressed:(){try{store.setCartQuantity(line.product.id,line.quantity+1);}catch(e){showError(context,e);}}),
      ])]))),
      if(store.cart.isNotEmpty)...[
        const SizedBox(height:16),Row(children:[Expanded(child:TextField(controller:discount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Bill flat discount'),onChanged:(_)=>setState((){}))),const SizedBox(width:12),Expanded(child:TextField(controller:percent,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Bill discount %'),onChanged:(_)=>setState((){})))]),
        const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:customerId,decoration:const InputDecoration(labelText:'Customer'),items:[const DropdownMenuItem(value:null,child:Text('Walk-in (cash/card/UPI)')),...store.customers.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.name)))],onChanged:(v)=>setState(()=>customerId=v)),
        const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:mode,decoration:const InputDecoration(labelText:'Payment'),items:const['cash','upi','card','credit'].map((m)=>DropdownMenuItem(value:m,child:Text(m.toUpperCase()))).toList(),onChanged:(v)=>setState((){mode=v!;confirmed=false;})),
        if(mode=='upi'&&totals!=null)...[
          if(store.upiId.isNotEmpty)Center(child:QrImageView(data:InvoicePdfService().buildUpiUri(payeeVpa:store.upiId,payeeName:store.shopName!,amount:totals.total,reference:'ShopOS sale'),size:200,backgroundColor:Colors.white))
          else const ListTile(title:Text('Add your UPI ID in Settings to display a payment QR.')),
        ],
        if(mode=='upi'||mode=='card')CheckboxListTile(value:confirmed,onChanged:(v)=>setState(()=>confirmed=v!),title:const Text('I verified that payment was received'),subtitle:const Text('A QR scan alone does not confirm a payment.')),
        if(totals!=null)...[ListTile(title:const Text('Subtotal'),trailing:Text(rupees(totals.subtotal))),ListTile(title:const Text('Discount'),trailing:Text(rupees(totals.billDiscount))),ListTile(title:const Text('GST'),trailing:Text(rupees(totals.tax))),ListTile(title:const Text('Grand total'),trailing:Text(rupees(totals.total),style:Theme.of(context).textTheme.titleLarge))],
        if(totalError!=null)Text(totalError,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        FilledButton.icon(onPressed:saving||totals==null?null:save,icon:const Icon(Icons.check),label:Text(saving?'Saving…':'Save bill')),
      ],
    ]);
  }
  @override void dispose(){discount.dispose();percent.dispose();super.dispose();}
}

Future<bool> confirm(BuildContext context,String title,String message) async => await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Confirm'))]))??false;

Future<void> openInvoice(BuildContext context,ShopStore store,Invoice invoice,{SupabaseClient? client})=>Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>InvoicePage(store:store,invoice:invoice,client:client)));
class InvoicePage extends StatelessWidget {
  const InvoicePage({required this.store,required this.invoice,this.client,super.key});final ShopStore store;final Invoice invoice;final SupabaseClient? client;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(invoice.number)),body:ListView(padding:const EdgeInsets.all(20),children:[
    Text(store.shopName!,style:Theme.of(context).textTheme.headlineSmall),Text(invoice.createdAt.toLocal().toString()),Text(invoice.customerName??'Walk-in customer'),
    Text('${invoice.paymentMode.toUpperCase()} • ${invoice.paymentMode=='credit'?'Due':'Paid (manually confirmed)'}'),const Divider(),
    ...invoice.lines.map((line)=>ListTile(title:Text(line.product.name),subtitle:Text('${line.quantity} × ${rupees(line.product.price)} • GST ${line.taxRate}%'),trailing:Text(rupees(line.total)))),
    ListTile(title:const Text('Discount'),trailing:Text(rupees(invoice.discount))),ListTile(title:const Text('GST'),trailing:Text(rupees(invoice.tax))),ListTile(title:const Text('Total'),trailing:Text(rupees(invoice.total))),
    const SizedBox(height:16),FilledButton.icon(icon:const Icon(Icons.print),label:const Text('Print / save PDF'),onPressed:()=>perform(context,()async{
      final service=InvoicePdfService();await Printing.layoutPdf(onLayout:(_)=>service.generate(shopName:store.shopName!,invoice:invoice,address:store.address,gstin:store.gstin,payeeVpa:store.upiId.isEmpty?null:store.upiId,paper:InvoicePaper.values.firstWhere((p)=>p.name==store.paper,orElse:()=>InvoicePaper.a4)));
    })),const SizedBox(height:8),OutlinedButton.icon(icon:const Icon(Icons.share),label:const Text('Share PDF (WhatsApp or other app)'),onPressed:()=>perform(context,()async{
      final bytes=await InvoicePdfService().generate(shopName:store.shopName!,invoice:invoice,address:store.address,gstin:store.gstin,payeeVpa:store.upiId.isEmpty?null:store.upiId);
      await Printing.sharePdf(bytes:bytes,filename:'${invoice.number}.pdf');
    })),
  ]));
}

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({required this.store,this.client,super.key});final ShopStore store;final SupabaseClient? client;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Invoices')),body:ListView(children:store.invoices.map((invoice)=>ListTile(title:Text(invoice.number),subtitle:Text('${invoice.paymentMode} • ${invoice.createdAt.toLocal()}'),trailing:Text(rupees(invoice.total)),onTap:()=>openInvoice(context,store,invoice,client:client))).toList()));
}

class ModulesPage extends StatefulWidget {
  const ModulesPage({required this.store,super.key});final ShopStore store;
  @override State<ModulesPage> createState()=>_ModulesPageState();
}
class _ModulesPageState extends State<ModulesPage> {
  String? entity;
  @override Widget build(BuildContext context){
    final entries=widget.store.schemas.entries.where((e)=>!['product','customer','invoice','ledger','stock_adjustment'].contains(e.key)).toList();
    entity??=entries.firstOrNull?.key;
    final schema=widget.store.schemas[entity];
    return Scaffold(appBar:AppBar(title:const Text('Shop modules')),body:ListView(padding:const EdgeInsets.all(16),children:[
      if(entries.isEmpty)const Text('No extra modules are published. Create an entity in the admin builder.'),
      if(entries.isNotEmpty)DropdownButton<String>(value:entity,items:entries.map((e)=>DropdownMenuItem(value:e.key,child:Text('${e.value['label']??e.key}'))).toList(),onChanged:(value)=>setState(()=>entity=value)),
      if(schema!=null)FilledButton(onPressed:()=>edit(schema),child:const Text('Add record')),
      ...(widget.store.records[entity]??[]).map((record)=>ListTile(title:Text('${record['name']??record['title']??record['id']}'),subtitle:Text(jsonEncode(record),maxLines:2,overflow:TextOverflow.ellipsis),onTap:()=>edit(schema!,record))),
    ]));
  }
  Future<void> edit(Map<String,dynamic> schema,[Map<String,dynamic>? record])async{
    final data=await editRecord(context,title:'${schema['label']}',entity:entity!,fields:schema['fields'],initial:record,store:widget.store);
    if(data!=null&&mounted)await perform(context,()=>widget.store.saveEntity(entity!,data,id:record?['id']));
  }
}
