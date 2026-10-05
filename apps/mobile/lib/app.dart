import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'data/local/shop_database.dart';
import 'data/local/shop_store.dart';
import 'data/remote/shop_session.dart';
import 'data/remote/supabase_auth_service.dart';
import 'features/shop_screens.dart' as shop;
import 'lowcode/builtin_field_types.dart';

class ShopOSApp extends StatefulWidget {
  const ShopOSApp({this.database, this.client, this.initialStore, super.key});
  final ShopDatabase? database;
  final SupabaseClient? client;
  final ShopStore? initialStore;
  @override State<ShopOSApp> createState() => _ShopOSAppState();
}

class _ShopOSAppState extends State<ShopOSApp> {
  late ShopStore store;
  ShopSession? session;
  StreamSubscription<AuthState>? authSubscription;
  String stage = 'welcome';
  String? error;
  bool loading = false;
  bool loadingSession = false;
  @override void initState() {
    super.initState();
    registerBuiltinFieldTypes();
    store = widget.initialStore ?? ShopStore(database: widget.database);
    if (store.isOnboarded) stage = 'shop';
    if (widget.database != null || widget.client != null) unawaited(initialize());
    authSubscription = widget.client?.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn && !loadingSession) unawaited(loadSession());
    });
  }
  Future<void> initialize() async {
    setState(() => loading = true);
    try {
      await store.initialize();
      if (widget.client?.auth.currentSession != null) { await loadSession(); }
      else if (mounted && store.isOnboarded) setState(() => stage = 'shop');
    } catch (failure) { if (mounted) setState(() => error = failure.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> loadSession() async {
    if (loadingSession || widget.client == null) return;
    loadingSession = true;
    if (mounted) setState(() { loading = true; error = null; });
    session?.dispose();
    final nextSession = ShopSession(widget.client!, widget.database!);
    try {
      final next = await nextSession.load();
      if (!mounted) { nextSession.dispose(); return; }
      setState(() { session = nextSession; if (next != null) store = next; stage = next == null ? 'onboarding' : 'shop'; });
    } catch (failure) { nextSession.dispose(); if (mounted) setState(() => error = failure.toString()); }
    finally { loadingSession = false; if (mounted) setState(() => loading = false); }
  }
  Future<void> localDemo() async {
    try {
      session?.dispose(); session = null;
      final local = ShopStore(database: widget.database);
      await local.initialize();
      if (mounted) setState(() { store = local; stage = local.isOnboarded ? 'shop' : 'onboarding'; error = null; });
    } catch (failure) { if (mounted) setState(() => error = failure.toString()); }
  }
  Future<void> signOut() async {
    if (!store.demo) await widget.client?.auth.signOut();
    session?.dispose(); session = null;
    if (mounted) setState(() { stage = 'welcome'; store = ShopStore(database: widget.database); });
  }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (context, _) => MaterialApp(
    title: 'ShopOS', debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme,
    themeMode: store.theme == 'dark' ? ThemeMode.dark : store.theme == 'light' ? ThemeMode.light : ThemeMode.system,
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(store.largeText ? 1.2 : 1)), child: child!),
    home: loading ? const Scaffold(body: Center(child: CircularProgressIndicator())) : stage == 'shop' ? shop.HomeScreen(store: store, session: session, client: store.demo ? null : widget.client, onSignOut: signOut)
      : stage == 'login' ? ShopLogin(client: widget.client!, onSignedIn: loadSession, onBack: () => setState(() => stage = 'welcome'))
      : stage == 'onboarding' ? ShopOnboarding(store: store, client: session == null ? null : widget.client, onCreated: () async { if (session != null) { await loadSession(); } else { setState(() => stage = 'shop'); } }, onBack: () => setState(() => stage = 'welcome'))
      : ShopWelcome(error: error, onDemo: localDemo, onLogin: widget.client == null ? null : () => setState(() => stage = 'login')),
  ));
  @override void dispose() { authSubscription?.cancel(); session?.dispose(); if (widget.initialStore == null) store.dispose(); super.dispose(); }
}

class ShopWelcome extends StatelessWidget {
  const ShopWelcome({required this.onDemo, this.onLogin, this.error, super.key});
  final Future<void> Function() onDemo;
  final VoidCallback? onLogin;
  final String? error;
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.storefront_outlined, size: 54, color: AppTheme.primaryColor), const SizedBox(height: 26),
    Text('ShopOS', style: Theme.of(context).textTheme.headlineLarge), const SizedBox(height: 14),
    Text('Run your shop from your phone', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12),
    const Text('A little simpler. Every day.\nBilling, stock, customers, and invoices in one thoughtful workspace.'), const SizedBox(height: 30),
    if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 16)],
    if (onLogin != null) ...[SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onLogin, icon: const Icon(Icons.login), label: const Text('Sign in to your shop'))), const SizedBox(height: 12)],
    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => onDemo(), icon: const Icon(Icons.add_business), label: const Text('Create shop'))),
    const SizedBox(height: 14), const Text('Explore a local demo. Your records stay on this device.', style: TextStyle(fontSize: 12, color: Colors.grey)),
  ]))))));
}

class ShopLogin extends StatefulWidget {
  const ShopLogin({required this.client, required this.onSignedIn, required this.onBack, super.key});
  final SupabaseClient client;
  final Future<void> Function() onSignedIn;
  final VoidCallback onBack;
  @override State<ShopLogin> createState() => _ShopLoginState();
}
class _ShopLoginState extends State<ShopLogin> {
  final phone = TextEditingController(), token = TextEditingController();
  bool sent = false, busy = false;
  String? error;
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      final auth = SupabaseAuthService(widget.client);
      if (sent) { await auth.verifyOtp(phone: phone.text, token: token.text); await widget.onSignedIn(); }
      else { await auth.sendOtp(phone.text); if (mounted) setState(() => sent = true); }
    } catch (failure) { if (mounted) setState(() => error = failure.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)), title: const Text('Welcome back')), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Your shop is right here.', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 24),
    TextField(controller: phone, enabled: !sent && !busy, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ')), const SizedBox(height: 16),
    if (sent) ...[TextField(controller: token, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Verification code')), const SizedBox(height: 16)],
    if (error != null) ...[Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 12)],
    FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'One moment…' : sent ? 'Open my shop' : 'Send verification code')),
    if (sent) TextButton(onPressed: busy ? null : () => setState(() => sent = false), child: const Text('Use another number')),
  ])))));
  @override void dispose() { phone.dispose(); token.dispose(); super.dispose(); }
}

class ShopOnboarding extends StatefulWidget {
  const ShopOnboarding({required this.store, this.client, required this.onCreated, required this.onBack, super.key});
  final ShopStore store;
  final SupabaseClient? client;
  final Future<void> Function() onCreated;
  final VoidCallback onBack;
  @override State<ShopOnboarding> createState() => _ShopOnboardingState();
}
class _ShopOnboardingState extends State<ShopOnboarding> {
  final name = TextEditingController(), address = TextEditingController();
  String template = 'retail_basic'; bool samples = true, saving = false;
  String? error;
  Future<void> save() async {
    if (saving) return; setState(() { saving = true; error = null; });
    try {
      if (widget.client != null) { await SupabaseAuthService(widget.client!).createTenant(name: name.text, shopType: template == 'retail_basic' ? 'retail' : template, templateKey: template, address: {'text': address.text}); await widget.client!.auth.refreshSession(); }
      else { await widget.store.createShop(name.text, template, sampleData: samples, shopAddress: address.text); if (samples && widget.store.customers.isEmpty) await widget.store.addCustomer('Priya Sharma', '9876543211'); }
      await widget.onCreated();
    } catch (failure) { if (mounted) setState(() => error = failure.toString()); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)), title: const Text('Make it your shop')), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('A fresh start for your business.', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 10), const Text('Choose a template and add your shop details. You can fine-tune them anytime.'), const SizedBox(height: 28),
    TextField(controller: name, decoration: const InputDecoration(labelText: 'Shop name')), const SizedBox(height: 16), TextField(controller: address, decoration: const InputDecoration(labelText: 'Shop address')), const SizedBox(height: 16),
    DropdownButtonFormField<String>(initialValue: template, decoration: const InputDecoration(labelText: 'Shop template'), items: const [DropdownMenuItem(value: 'retail_basic', child: Text('Retail / grocery')), DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacy')), DropdownMenuItem(value: 'salon', child: Text('Salon')), DropdownMenuItem(value: 'restaurant', child: Text('Restaurant')), DropdownMenuItem(value: 'boutique', child: Text('Boutique')), DropdownMenuItem(value: 'repair', child: Text('Repair & services'))], onChanged: saving ? null : (value) => setState(() => template = value!)),
    if (widget.client == null) CheckboxListTile(contentPadding: EdgeInsets.zero, value: samples, onChanged: saving ? null : (value) => setState(() => samples = value!), title: const Text('Include sample products and a customer')),
    if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    const SizedBox(height: 20), FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.storefront), label: Text(saving ? 'Creating your shop…' : 'Create my shop')),
  ])))));
  @override void dispose() { name.dispose(); address.dispose(); super.dispose(); }
}
