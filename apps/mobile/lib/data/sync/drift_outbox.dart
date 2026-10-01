import 'dart:convert';

import 'package:drift/drift.dart';

import '../local/shop_database.dart';
import '../../domain/shop_models.dart';
import 'outbox.dart';

class DriftOutboxStore implements OutboxStore {
  DriftOutboxStore(this.database, {this.tenantId, DateTime Function()? now}) : now = now ?? DateTime.now;
  final ShopDatabase database;
  final String? tenantId;
  final DateTime Function() now;

  @override
  Future<void> add(QueuedMutation mutation) =>
      database.into(database.queuedActions).insert(
            QueuedActionsCompanion.insert(
              id: mutation.id,
              entity: mutation.entity,
              action: mutation.action,
              payload: jsonEncode(mutation.payload),
              createdAt: mutation.createdAt,
            ),
          );

  @override
  Future<int> count() async {
    return (await all()).length;
  }

  @override
  Future<List<QueuedMutation>> pending({int limit = 100}) async {
    final rows = await all();
    // A deferred head blocks later changes: never overtake a failed sale.
    return rows.takeWhile((row) => row.nextAttemptAt == null || !row.nextAttemptAt!.isAfter(now())).take(limit).toList();
  }

  Future<List<QueuedMutation>> all() async {
    final rows = await (database.select(database.queuedActions)
          ..where((action) => action.status.equals('pending'))
          ..orderBy([(action) => OrderingTerm.asc(action.createdAt), (action) => OrderingTerm.asc(action.rowId)]))
        .get();
    return rows
        .where((row) =>
            tenantId == null || (jsonDecode(row.payload) as Map)['_tenant_id'] == tenantId)
        .map((row) => QueuedMutation(
              id: row.id,
              entity: row.entity,
              action: row.action,
              payload:
                  Map<String, dynamic>.from(jsonDecode(row.payload) as Map),
              createdAt: row.createdAt,
              attempts: row.retryCount,
              nextAttemptAt: row.nextAttemptAt,
            ))
        .toList();
  }

  @override
  Future<void> remove(String id) => (database.delete(database.queuedActions)
        ..where((row) => row.id.equals(id)))
      .go();

  @override
  Future<void> replace(QueuedMutation mutation) =>
      database.update(database.queuedActions).replace(
            QueuedAction(
              id: mutation.id,
              entity: mutation.entity,
              action: mutation.action,
              payload: jsonEncode(mutation.payload),
              status: 'pending',
              retryCount: mutation.attempts,
              createdAt: mutation.createdAt,
              nextAttemptAt: mutation.nextAttemptAt ?? now()
                  .add(Duration(seconds: 5 * (1 << (mutation.attempts - 1).clamp(0, 6)))),
            ),
          );
}
