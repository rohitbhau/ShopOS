import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/env.dart';
import 'data/local/database_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = await openShopDatabase();
  if (Env.configured) {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  }
  
  runApp(
    ProviderScope(
      child: ShopOSApp(database: database, client: Env.configured ? Supabase.instance.client : null),
    ),
  );
}
