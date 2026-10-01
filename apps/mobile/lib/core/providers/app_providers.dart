// App-wide providers for dependency injection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import '../sync/sync_service.dart';
import '../sync/connectivity_manager.dart';

// Database provider (singleton)
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final supabase = ref.watch(supabaseProvider);
  return SyncService(db, supabase);
});

// Connectivity manager provider
final connectivityManagerProvider = ChangeNotifierProvider<ConnectivityManager>((ref) {
  final manager = ConnectivityManager();
  
  // Auto-sync when coming back online
  final syncService = ref.read(syncServiceProvider);
  manager.registerOnlineCallback(() async {
    print('Auto-syncing after coming online...');
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final tenantId = user.userMetadata?['tenant_id'];
        if (tenantId != null) {
          await syncService.sync(tenantId);
          print('✅ Auto-sync completed');
        }
      }
    } catch (e) {
      print('❌ Auto-sync failed: $e');
    }
  });
  
  return manager;
});

// Current tenant ID provider
final currentTenantIdProvider = FutureProvider<String?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  
  if (user == null) return null;
  
  // Try to get from user metadata first
  final tenantId = user.userMetadata?['tenant_id'];
  if (tenantId != null) return tenantId as String;
  
  // Fallback: query memberships table
  try {
    final membership = await supabase
        .from('memberships')
        .select('tenant_id')
        .eq('user_id', user.id)
        .single();
    return membership['tenant_id'] as String;
  } catch (e) {
    print('Failed to get tenant_id: $e');
    return null;
  }
});

// Sync status provider (for UI feedback)
final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier();
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(SyncStatus.idle);

  void setSyncing() => state = SyncStatus.syncing;
  void setSuccess() => state = SyncStatus.success;
  void setError(String message) => state = SyncStatus.error;
  void setIdle() => state = SyncStatus.idle;
}

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}
