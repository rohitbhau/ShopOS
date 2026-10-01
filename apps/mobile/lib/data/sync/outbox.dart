import '../../domain/shop_models.dart';

abstract class OutboxStore {
  Future<void> add(QueuedMutation mutation);
  Future<List<QueuedMutation>> pending({int limit = 100});
  Future<void> remove(String id);
  Future<void> replace(QueuedMutation mutation);
  Future<int> count();
}

class MemoryOutboxStore implements OutboxStore {
  MemoryOutboxStore({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  final List<QueuedMutation> _items = [];
  @override
  Future<void> add(QueuedMutation mutation) async => _items.add(mutation);
  @override
  Future<int> count() async => _items.length;
  @override
  Future<List<QueuedMutation>> pending({int limit = 100}) async {
    final ordered = List<QueuedMutation>.of(_items)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ordered.takeWhile((row)=>row.nextAttemptAt == null || !row.nextAttemptAt!.isAfter(now())).take(limit).toList();
  }
  @override
  Future<void> remove(String id) async => _items.removeWhere((item) => item.id == id);
  @override
  Future<void> replace(QueuedMutation mutation) async {
    final index = _items.indexWhere((item) => item.id == mutation.id);
    if (index != -1) _items[index] = mutation;
  }
}
