// Drift database definition for offline storage
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Products table
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  RealColumn get price => real()();
  RealColumn get cost => real().nullable()();
  IntColumn get stock => integer()();
  IntColumn get minStock => integer().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().nullable()();
  RealColumn get gstRate => real().withDefault(const Constant(18.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Customers table
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get outstanding => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Invoices table
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceNumber => text()();
  DateTimeColumn get invoiceDate => dateTime()();
  TextColumn get customerId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get taxAmount => real()();
  RealColumn get total => real()();
  TextColumn get paymentMode => text()(); // cash, upi, card, credit
  TextColumn get paymentStatus => text()(); // paid, pending, partial
  TextColumn get itemsJson => text()(); // JSON array of items
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Customer ledger entries table
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()(); // sale, payment, adjustment
  TextColumn get invoiceNumber => text().nullable()();
  TextColumn get description => text()();
  RealColumn get debit => real().withDefault(const Constant(0.0))();
  RealColumn get credit => real().withDefault(const Constant(0.0))();
  RealColumn get balance => real()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// Outbox table for queued operations
class OutboxQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()(); // insert, update, delete
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get recordId => text()();
  TextColumn get dataJson => text()(); // JSON payload
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
}

// Sync metadata table
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Products,
  Customers,
  Invoices,
  LedgerEntries,
  OutboxQueue,
  SyncMetadata,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future schema upgrades
      },
    );
  }

  // Products queries
  Future<List<Product>> getAllProducts(String tenantId) {
    return (select(products)
          ..where((p) => p.tenantId.equals(tenantId))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .get();
  }

  Future<Product?> getProductById(String id) {
    return (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<List<Product>> searchProducts(String tenantId, String query) {
    final lowerQuery = query.toLowerCase();
    return (select(products)
          ..where((p) =>
              p.tenantId.equals(tenantId) &
              (p.name.lower().contains(lowerQuery) |
                  p.sku.lower().contains(lowerQuery))))
        .get();
  }

  Future<List<Product>> getLowStockProducts(String tenantId) {
    return (select(products)
          ..where((p) =>
              p.tenantId.equals(tenantId) &
              p.stock.isSmallerOrEqual(p.minStock)))
        .get();
  }

  Future<int> insertProduct(Product product) {
    return into(products).insert(product);
  }

  Future<bool> updateProduct(Product product) {
    return update(products).replace(product);
  }

  Future<int> deleteProduct(String id) {
    return (delete(products)..where((p) => p.id.equals(id))).go();
  }

  Future<void> markProductDirty(String id) {
    return (update(products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(isDirty: const Value(true)));
  }

  Future<List<Product>> getDirtyProducts(String tenantId) {
    return (select(products)
          ..where((p) => p.tenantId.equals(tenantId) & p.isDirty.equals(true)))
        .get();
  }

  // Customers queries
  Future<List<Customer>> getAllCustomers(String tenantId) {
    return (select(customers)
          ..where((c) => c.tenantId.equals(tenantId))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  Future<Customer?> getCustomerById(String id) {
    return (select(customers)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Customer>> searchCustomers(String tenantId, String query) {
    final lowerQuery = query.toLowerCase();
    return (select(customers)
          ..where((c) =>
              c.tenantId.equals(tenantId) &
              (c.name.lower().contains(lowerQuery) |
                  c.phone.contains(query))))
        .get();
  }

  Future<List<Customer>> getCustomersWithOutstanding(String tenantId) {
    return (select(customers)
          ..where((c) =>
              c.tenantId.equals(tenantId) & c.outstanding.isBiggerThanValue(0))
          ..orderBy([(c) => OrderingTerm.desc(c.outstanding)]))
        .get();
  }

  Future<int> insertCustomer(Customer customer) {
    return into(customers).insert(customer);
  }

  Future<bool> updateCustomer(Customer customer) {
    return update(customers).replace(customer);
  }

  Future<void> markCustomerDirty(String id) {
    return (update(customers)..where((c) => c.id.equals(id)))
        .write(CustomersCompanion(isDirty: const Value(true)));
  }

  Future<List<Customer>> getDirtyCustomers(String tenantId) {
    return (select(customers)
          ..where((c) => c.tenantId.equals(tenantId) & c.isDirty.equals(true)))
        .get();
  }

  // Invoices queries
  Future<List<Invoice>> getAllInvoices(String tenantId) {
    return (select(invoices)
          ..where((i) => i.tenantId.equals(tenantId))
          ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
        .get();
  }

  Future<Invoice?> getInvoiceById(String id) {
    return (select(invoices)..where((i) => i.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Invoice>> getInvoicesByDateRange(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return (select(invoices)
          ..where((i) =>
              i.tenantId.equals(tenantId) &
              i.invoiceDate.isBiggerOrEqualValue(startDate) &
              i.invoiceDate.isSmallerOrEqualValue(endDate))
          ..orderBy([(i) => OrderingTerm.desc(i.invoiceDate)]))
        .get();
  }

  Future<List<Invoice>> getPendingInvoices(String tenantId) {
    return (select(invoices)
          ..where((i) =>
              i.tenantId.equals(tenantId) &
              i.paymentStatus.equals('pending')))
        .get();
  }

  Future<int> insertInvoice(Invoice invoice) {
    return into(invoices).insert(invoice);
  }

  Future<bool> updateInvoice(Invoice invoice) {
    return update(invoices).replace(invoice);
  }

  Future<void> markInvoiceDirty(String id) {
    return (update(invoices)..where((i) => i.id.equals(id)))
        .write(InvoicesCompanion(isDirty: const Value(true)));
  }

  Future<List<Invoice>> getDirtyInvoices(String tenantId) {
    return (select(invoices)
          ..where((i) => i.tenantId.equals(tenantId) & i.isDirty.equals(true)))
        .get();
  }

  // Ledger entries queries
  Future<List<LedgerEntry>> getCustomerLedger(String customerId) {
    return (select(ledgerEntries)
          ..where((l) => l.customerId.equals(customerId))
          ..orderBy([(l) => OrderingTerm.desc(l.date)]))
        .get();
  }

  Future<int> insertLedgerEntry(LedgerEntry entry) {
    return into(ledgerEntries).insert(entry);
  }

  Future<List<LedgerEntry>> getDirtyLedgerEntries(String customerId) {
    return (select(ledgerEntries)
          ..where((l) => l.customerId.equals(customerId) & l.isDirty.equals(true)))
        .get();
  }

  // Outbox queries
  Future<List<OutboxQueueData>> getPendingOutboxItems() {
    return (select(outboxQueue)
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
        .get();
  }

  Future<int> insertOutboxItem(OutboxQueueData item) {
    return into(outboxQueue).insert(item);
  }

  Future<int> deleteOutboxItem(int id) {
    return (delete(outboxQueue)..where((o) => o.id.equals(id))).go();
  }

  Future<void> updateOutboxItemRetry(int id, String errorMessage) async {
    final item = await (select(outboxQueue)..where((o) => o.id.equals(id))).getSingleOrNull();
    if (item == null) return;
    await (update(outboxQueue)..where((o) => o.id.equals(id))).write(
      OutboxQueueCompanion(
        retryCount: Value(item.retryCount + 1),
        lastAttemptAt: Value(DateTime.now()),
        errorMessage: Value(errorMessage),
      ),
    );
  }

  Future<int> clearProcessedOutboxItems() {
    // Clear items older than 7 days
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    return (delete(outboxQueue)
          ..where((o) => o.createdAt.isSmallerThanValue(cutoffDate)))
        .go();
  }

  // Sync metadata queries
  Future<String?> getSyncMetadata(String key) async {
    final result = await (select(syncMetadata)
          ..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return result?.value;
  }

  Future<void> setSyncMetadata(String key, String value) {
    return into(syncMetadata).insertOnConflictUpdate(
      SyncMetadataData(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final value = await getSyncMetadata('last_sync_time');
    return value != null ? DateTime.parse(value) : null;
  }

  Future<void> setLastSyncTime(DateTime time) {
    return setSyncMetadata('last_sync_time', time.toIso8601String());
  }

  // Clear all data (for logout)
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(products).go();
      await delete(customers).go();
      await delete(invoices).go();
      await delete(ledgerEntries).go();
      await delete(outboxQueue).go();
      await delete(syncMetadata).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'shopos.db'));
    return NativeDatabase(file);
  });
}
