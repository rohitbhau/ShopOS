import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/shop_models.dart';
import 'outbox.dart';

enum SyncState { synced, syncing, offline, pending, error }

class SyncStatus {
  const SyncStatus({required this.state, this.pendingCount = 0, this.errorMessage});
  final SyncState state;
  final int pendingCount;
  final String? errorMessage;
}

abstract class RemoteSyncGateway {
  Future<void> push(QueuedMutation mutation);
}

class SyncEngine {
  SyncEngine({required this.outbox, required this.gateway, this.isOnline = _alwaysOnline, this.onSynced, DateTime Function()? now}) : now = now ?? DateTime.now;
  final OutboxStore outbox;
  final RemoteSyncGateway gateway;
  final Future<bool> Function() isOnline;
  final Future<void> Function()? onSynced;
  final DateTime Function() now;
  SyncStatus currentStatus = const SyncStatus(state: SyncState.pending);
  Timer? _timer;
  bool _disposed = false;
  final _status = StreamController<SyncStatus>.broadcast();
  bool _syncing = false;

  Stream<SyncStatus> get statusStream => _status.stream;
  void start() { _timer ??= Timer.periodic(const Duration(seconds:30), (_) => syncNow()); syncNow(); }
  void _emit(SyncStatus status) { currentStatus=status; if(!_disposed) _status.add(status); }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    try {
      if (!await isOnline()) {
        _emit(SyncStatus(state: SyncState.offline, pendingCount: await outbox.count()));
        return;
      }
      _emit(SyncStatus(state: SyncState.syncing, pendingCount: await outbox.count()));
      while (true) {
        final pending = await outbox.pending(limit: 100);
        if (pending.isEmpty) break;
        for (final action in pending) {
          try {
            await gateway.push(action);
            await outbox.remove(action.id);
          } catch (error) {
            await outbox.replace(QueuedMutation(
              id: action.id, entity: action.entity, action: action.action, payload: action.payload,
              createdAt: action.createdAt, attempts: action.attempts + 1,
              nextAttemptAt: now().add(Duration(seconds:5*(1<<action.attempts.clamp(0,6)))),
            ));
            _emit(SyncStatus(state: SyncState.pending, pendingCount: await outbox.count(), errorMessage: error.toString()));
            return;
          }
        }
      }
      final remaining=await outbox.count();
      if(remaining==0) await onSynced?.call();
      _emit(SyncStatus(state:remaining==0?SyncState.synced:SyncState.pending,pendingCount:remaining));
    } catch(error) {
      _emit(SyncStatus(state:SyncState.error,pendingCount:await outbox.count(),errorMessage:error.toString()));
    } finally {
      _syncing = false;
    }
  }

  void dispose() { _disposed=true; _timer?.cancel(); _status.close(); }
}

Future<bool> _alwaysOnline() async => true;
final syncEngineProvider = Provider<SyncEngine>((_) => throw UnimplementedError('Provide a SyncEngine at application bootstrap.'));
