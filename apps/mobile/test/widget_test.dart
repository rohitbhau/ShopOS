// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:shopos/app.dart';
import 'package:shopos/data/local/shop_store.dart';

void main() {
  testWidgets('ShopOS starts at shop onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ShopOSApp());

    expect(find.text('Run your shop from your phone'), findsOneWidget);
    expect(find.text('Create shop'), findsOneWidget);
  });
  for (final width in [360.0, 1024.0]) {
    testWidgets('persistent shop screens render at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ShopStore();
      await store.createShop('Maya Store', 'retail_basic', sampleData: true);
      await store.addCustomer('Priya Sharma', '9876543211');
      await tester.pumpWidget(ShopOSApp(initialStore: store));
      await tester.pumpAndSettle();
      expect(find.text('A good day starts here.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sell').last);
      await tester.pumpAndSettle();
      expect(find.text('New bill'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink()); store.dispose();
    });
  }
}
