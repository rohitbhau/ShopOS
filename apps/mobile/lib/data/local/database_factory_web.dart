// Drift's current SQL.js backend is deprecated but remains the compatible
// browser backend until the Wasm worker assets are bundled.
// ignore_for_file: deprecated_member_use

import 'package:drift/web.dart';

import 'shop_database.dart';

Future<ShopDatabase> openShopDatabase() async =>
    ShopDatabase(WebDatabase('shopos'));
