// Sync status widget - shows online/offline status and sync button
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../sync/connectivity_manager.dart';

class SyncStatusWidget extends ConsumerWidget {
  final bool compact;

  const SyncStatusWidget({
    Key? key,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityManagerProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final syncService = ref.read(syncServiceProvider);
    final tenantIdAsync = ref.watch(currentTenantIdProvider);

    if (compact) {
      return _buildCompactView(context, connectivity, syncStatus);
    }

    return tenantIdAsync.when(
      data: (tenantId) => _buildFullView(
        context,
        connectivity,
        syncStatus,
        tenantId,
        syncService,
        ref,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCompactView(
    BuildContext context,
    ConnectivityManager connectivity,
    SyncStatus syncStatus,
  ) {
    IconData icon;
    Color color;
    String tooltip;

    if (syncStatus == SyncStatus.syncing) {
      icon = Icons.sync;
      color = Colors.blue;
      tooltip = 'Syncing...';
    } else if (connectivity.isOffline) {
      icon = Icons.cloud_off;
      color = Colors.orange;
      tooltip = 'Offline mode';
    } else {
      icon = Icons.cloud_done;
      color = AppTheme.successColor;
      tooltip = 'Online';
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildFullView(
    BuildContext context,
    ConnectivityManager connectivity,
    SyncStatus syncStatus,
    String? tenantId,
    dynamic syncService,
    WidgetRef ref,
  ) {
    final isOnline = connectivity.isOnline;
    final isSyncing = syncStatus == SyncStatus.syncing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOnline
            ? AppTheme.successColor.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOnline ? AppTheme.successColor : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: isOnline ? AppTheme.successColor : Colors.orange,
            ),
          const SizedBox(width: 8),
          Text(
            isSyncing
                ? 'Syncing...'
                : isOnline
                    ? 'Online'
                    : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOnline ? AppTheme.successColor : Colors.orange,
            ),
          ),
          if (isOnline && !isSyncing && tenantId != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _performSync(context, ref, syncService, tenantId),
              child: const Icon(
                Icons.sync,
                size: 16,
                color: Colors.blue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _performSync(
    BuildContext context,
    WidgetRef ref,
    dynamic syncService,
    String tenantId,
  ) async {
    final notifier = ref.read(syncStatusProvider.notifier);
    notifier.setSyncing();

    try {
      final result = await syncService.sync(tenantId);
      
      if (result.success) {
        notifier.setSuccess();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sync completed: ${result.pulledProducts + result.pulledCustomers + result.pulledInvoices} records updated',
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Reset to idle after showing success
        Future.delayed(const Duration(seconds: 2), () {
          notifier.setIdle();
        });
      } else {
        notifier.setError(result.message);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: ${result.message}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        
        Future.delayed(const Duration(seconds: 3), () {
          notifier.setIdle();
        });
      }
    } catch (e) {
      notifier.setError(e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      
      Future.delayed(const Duration(seconds: 3), () {
        notifier.setIdle();
      });
    }
  }
}

// Floating sync button for easy access
class FloatingSyncButton extends ConsumerWidget {
  const FloatingSyncButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityManagerProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final tenantIdAsync = ref.watch(currentTenantIdProvider);

    if (connectivity.isOffline) {
      return const SizedBox.shrink();
    }

    return tenantIdAsync.when(
      data: (tenantId) {
        if (tenantId == null) return const SizedBox.shrink();

        return FloatingActionButton.small(
          onPressed: syncStatus == SyncStatus.syncing
              ? null
              : () => _sync(context, ref, tenantId),
          child: syncStatus == SyncStatus.syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync, size: 20),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref, String tenantId) async {
    final syncService = ref.read(syncServiceProvider);
    final notifier = ref.read(syncStatusProvider.notifier);

    notifier.setSyncing();

    try {
      final result = await syncService.sync(tenantId);
      
      if (result.success) {
        notifier.setSuccess();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Sync completed'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        Future.delayed(const Duration(seconds: 2), () {
          notifier.setIdle();
        });
      } else {
        notifier.setError(result.message);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result.message}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        
        Future.delayed(const Duration(seconds: 3), () {
          notifier.setIdle();
        });
      }
    } catch (e) {
      notifier.setError(e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      
      Future.delayed(const Duration(seconds: 3), () {
        notifier.setIdle();
      });
    }
  }
}
