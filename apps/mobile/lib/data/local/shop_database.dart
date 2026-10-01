import 'dart:convert';

import 'package:drift/drift.dart';

part 'shop_database.g.dart';

class LocalRecords extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().nullable()();
  TextColumn get entity => text()();
  TextColumn get data => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class QueuedActions extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()();
  TextColumn get action => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  DateTimeColumn get value => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [LocalRecords, QueuedActions, SyncMetadata])
class ShopDatabase extends _$ShopDatabase {
  ShopDatabase(super.e);

  @override
  int get schemaVersion => 1;

  Future<Map<String,dynamic>?> readJson(String id) async {
    final row=await (select(localRecords)..where((item)=>item.id.equals(id))).getSingleOrNull();
    return row==null?null:Map<String,dynamic>.from(jsonDecode(row.data));
  }

  Future<void> saveRecord({
    required String id,
    String? tenantId,
    required String entity,
    required Map<String, dynamic> data,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) =>
      into(localRecords).insertOnConflictUpdate(
        LocalRecordsCompanion.insert(
          id: id,
          tenantId: Value(tenantId),
          entity: entity,
          data: jsonEncode(data),
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: Value(deletedAt),
        ),
      );

  Stream<List<LocalRecord>> watchEntity(String entity) => (select(localRecords)
        ..where((record) => record.entity.equals(entity))
        ..where((record) => record.deletedAt.isNull())
        ..orderBy([(record) => OrderingTerm.desc(record.updatedAt)]))
      .watch();

  Future<DateTime?> lastSyncedAt() async =>
      (select(syncMetadata)..where((item) => item.key.equals('last_synced_at')))
          .getSingleOrNull()
          .then((row) => row?.value);

  Future<void> setLastSyncedAt(DateTime value) =>
      into(syncMetadata).insertOnConflictUpdate(
        SyncMetadataCompanion.insert(
            key: 'last_synced_at', value: Value(value)),
      );
}
