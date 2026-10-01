import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopos/data/local/shop_store.dart';
import 'package:shopos/data/sync/outbox.dart';
import 'package:shopos/data/sync/drift_outbox.dart';
import 'package:shopos/data/sync/sync_engine.dart';
import 'package:shopos/data/local/shop_database.dart';
import 'package:shopos/core/services/invoice_pdf_service.dart';
import 'package:shopos/domain/shop_models.dart';

class RecordingGateway implements RemoteSyncGateway {
  final pushed = <String>[];
  int failuresRemaining = 0;

  @override
  Future<void> push(QueuedMutation mutation) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('temporary network failure');
    }
    pushed.add(mutation.id);
  }
}

void main() {
  group('ShopStore end-to-end sale flow', () {
    test('onboards, creates a product, and saves a credit sale offline', () {
      final store = ShopStore();

      store.createShop('Maya General Store', 'retail_basic');
      store.addProduct({'name': 'Tea', 'price': '120', 'stock': '6'});
      final product = store.products.last;
      final customer = store.customers.first;
      store.addToCart(product);

      final invoice = store.checkout(paymentMode: 'credit', customer: customer);

      expect(store.isOnboarded, isTrue);
      expect(invoice.total, 120);
      expect(store.invoices, hasLength(1));
      expect(store.products.last.stock, 5);
      expect(store.customers.first.outstanding, 120);
      expect(store.outbox.map((item) => item.entity),
          containsAllInOrder(['tenant', 'product', 'invoice']));
    });
  });

  group('SyncEngine', () {
    test('pushes queued actions in creation order', () async {
      final outbox = MemoryOutboxStore();
      final gateway = RecordingGateway();
      final now = DateTime(2026, 1, 1);
      await outbox.add(QueuedMutation(
          id: 'first',
          entity: 'product',
          action: 'create',
          payload: {},
          createdAt: now));
      await outbox.add(QueuedMutation(
          id: 'second',
          entity: 'invoice',
          action: 'create',
          payload: {},
          createdAt: now.add(const Duration(seconds: 1))));
      final engine = SyncEngine(outbox: outbox, gateway: gateway);

      await engine.syncNow();

      expect(gateway.pushed, ['first', 'second']);
      expect(await outbox.count(), 0);
      engine.dispose();
    });

    test('retains an action and increments attempts after a network failure',
        () async {
      final outbox = MemoryOutboxStore();
      final gateway = RecordingGateway()..failuresRemaining = 1;
      await outbox.add(QueuedMutation(
          id: 'retry-me',
          entity: 'invoice',
          action: 'create',
          payload: {},
          createdAt: DateTime.now()));
      final engine = SyncEngine(outbox: outbox, gateway: gateway);

      await engine.syncNow();
      final pending = await outbox.pending();

      expect(pending.single.id, 'retry-me');
      expect(pending.single.attempts, 1);
      expect(gateway.pushed, isEmpty);
      engine.dispose();
    });

    test('reports offline without removing queued work', () async {
      final outbox = MemoryOutboxStore();
      await outbox.add(QueuedMutation(
          id: 'offline',
          entity: 'product',
          action: 'create',
          payload: {},
          createdAt: DateTime.now()));
      final engine = SyncEngine(
          outbox: outbox,
          gateway: RecordingGateway(),
          isOnline: () async => false);

      await engine.syncNow();

      expect(await outbox.count(), 1);
      engine.dispose();
    });
  });

  test('persists queued actions and records across database reopen', () async {
    final directory = await Directory.systemTemp.createTemp('shopos-db-');
    final file =
        File('${directory.path}${Platform.pathSeparator}shopos.sqlite');
    final firstDatabase = ShopDatabase(NativeDatabase(file));
    final firstOutbox = DriftOutboxStore(firstDatabase);
    final createdAt = DateTime(2026, 1, 1, 10);

    await firstDatabase.saveRecord(
      id: 'product-1',
      tenantId: 'tenant-1',
      entity: 'product',
      data: {'name': 'Tea', 'stock': 4},
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    await firstOutbox.add(QueuedMutation(
      id: 'action-1',
      entity: 'product',
      action: 'create',
      payload: {'name': 'Tea'},
      createdAt: createdAt,
    ));
    await firstDatabase.close();

    final reopenedDatabase = ShopDatabase(NativeDatabase(file));
    final reopenedOutbox = DriftOutboxStore(reopenedDatabase);
    final pending = await reopenedOutbox.pending();
    final records =
        await reopenedDatabase.select(reopenedDatabase.localRecords).get();

    expect(pending.single.payload['name'], 'Tea');
    expect(records.single.data, contains('Tea'));
    expect(await reopenedOutbox.count(), 1);

    await reopenedDatabase.close();
    await directory.delete(recursive: true);
  });

  test('builds a UPI URI and non-empty invoice PDF', () async {
    final invoice = Invoice(
      id: 'invoice-1',
      number: 'SHOP-20260101-0001',
      createdAt: DateTime(2026, 1, 1),
      lines: const [
        CartLine(
            product: Product(id: 'tea', name: 'Tea', price: 120, stock: 1),
            quantity: 2),
      ],
      total: 240,
      paymentMode: 'upi',
    );
    final service = InvoicePdfService();

    final uri = service.buildUpiUri(
      payeeVpa: 'shop@upi',
      payeeName: 'Maya Store',
      amount: invoice.total,
      reference: invoice.number,
    );
    final pdf = await service.generate(
      shopName: 'Maya Store',
      invoice: invoice,
      payeeVpa: 'shop@upi',
      paper: InvoicePaper.roll80,
    );

    expect(uri, startsWith('upi://pay?'));
    expect(uri, contains('shop%40upi'));
    expect(uri, contains('am=240.00'));
    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf), contains('%PDF'));
  });
}
