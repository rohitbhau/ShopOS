import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'shop_database.dart';

Future<ShopDatabase> openShopDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  return ShopDatabase(
    NativeDatabase(
        File('${directory.path}${Platform.pathSeparator}shopos.sqlite')),
  );
}
