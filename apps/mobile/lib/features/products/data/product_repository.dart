// Product repository - offline-first data access layer
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/sync/connectivity_manager.dart';

class ProductRepository {
  final AppDatabase _db;
  final SyncService _syncService;
  final ConnectivityManager _connectivity;

  ProductRepository(this._db, this._syncService, this._connectivity);

  // Get all products (always from local DB)
  Future<List<Product>> getProducts(String tenantId) async {
    return await _db.getAllProducts(tenantId);
  }

  // Search products (local DB)
  Future<List<Product>> searchProducts(String tenantId, String query) async {
    return await _db.searchProducts(tenantId, query);
  }

  // Get low stock products (local DB)
  Future<List<Product>> getLowStockProducts(String tenantId) async {
    return await _db.getLowStockProducts(tenantId);
  }

  // Get single product by ID (local DB)
  Future<Product?> getProductById(String id) async {
    return await _db.getProductById(id);
  }

  // Add new product (offline-first)
  Future<Product> addProduct(
    String tenantId,
    String name,
    String? sku,
    double price,
    double? cost,
    int stock,
    int? minStock,
    String? category,
    String? unit,
    double gstRate,
  ) async {
    final product = Product(
      id: const Uuid().v4(),
      tenantId: tenantId,
      name: name,
      sku: sku,
      price: price,
      cost: cost,
      stock: stock,
      minStock: minStock,
      category: category,
      unit: unit,
      gstRate: gstRate,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastSyncedAt: null,
      isDirty: true, // Mark as dirty for sync
    );

    // Save to local DB immediately
    await _db.insertProduct(product);

    // If online, try to sync immediately
    if (_connectivity.isOnline) {
      try {
        await _syncToServer(product);
      } catch (e) {
        print('Failed to sync product immediately, will sync later: $e');
        // Product is already saved locally and marked dirty
      }
    }

    return product;
  }

  // Update product (offline-first)
  Future<Product> updateProduct(
    Product product, {
    String? name,
    String? sku,
    double? price,
    double? cost,
    int? stock,
    int? minStock,
    String? category,
    String? unit,
    double? gstRate,
    bool? isActive,
  }) async {
    final updated = product.copyWith(
      name: name ?? product.name,
      sku: sku ?? product.sku,
      price: price ?? product.price,
      cost: cost ?? product.cost,
      stock: stock ?? product.stock,
      minStock: minStock ?? product.minStock,
      category: category ?? product.category,
      unit: unit ?? product.unit,
      gstRate: gstRate ?? product.gstRate,
      isActive: isActive ?? product.isActive,
      updatedAt: DateTime.now(),
      isDirty: true, // Mark as dirty for sync
    );

    await _db.updateProduct(updated);

    // If online, try to sync immediately
    if (_connectivity.isOnline) {
      try {
        await _syncToServer(updated);
      } catch (e) {
        print('Failed to sync product immediately, will sync later: $e');
      }
    }

    return updated;
  }

  // Update stock (common operation)
  Future<Product> updateStock(String id, int newStock) async {
    final product = await _db.getProductById(id);
    if (product == null) {
      throw Exception('Product not found');
    }

    return await updateProduct(product, stock: newStock);
  }

  // Delete product (soft delete)
  Future<void> deleteProduct(String id) async {
    final product = await _db.getProductById(id);
    if (product == null) return;

    // Mark as inactive instead of hard delete
    await updateProduct(product, isActive: false);
  }

  // Sync a single product to server
  Future<void> _syncToServer(Product product) async {
    final data = {
      'id': product.id,
      'tenant_id': product.tenantId,
      'data': {
        'name': product.name,
        'sku': product.sku,
        'price': product.price,
        'cost': product.cost,
        'stock': product.stock,
        'min_stock': product.minStock,
        'category': product.category,
        'unit': product.unit,
        'gst_rate': product.gstRate,
        'is_active': product.isActive,
      },
      'updated_at': product.updatedAt.toIso8601String(),
    };

    await _syncService.queueOperation('upsert', 'records', product.id, data);
  }

  // Batch operations
  Future<void> bulkUpdateStock(Map<String, int> stockUpdates) async {
    await _db.transaction(() async {
      for (final entry in stockUpdates.entries) {
        await updateStock(entry.key, entry.value);
      }
    });
  }

  // Get products needing sync
  Future<List<Product>> getDirtyProducts(String tenantId) async {
    return await _db.getDirtyProducts(tenantId);
  }

  // Get sync statistics
  Future<ProductSyncStats> getSyncStats(String tenantId) async {
    final all = await _db.getAllProducts(tenantId);
    final dirty = await _db.getDirtyProducts(tenantId);
    
    int notSynced = 0;
    DateTime? oldestPending;

    for (final product in dirty) {
      notSynced++;
      if (oldestPending == null || product.updatedAt.isBefore(oldestPending)) {
        oldestPending = product.updatedAt;
      }
    }

    return ProductSyncStats(
      total: all.length,
      synced: all.length - notSynced,
      pendingSync: notSynced,
      oldestPendingChange: oldestPending,
    );
  }
}

class ProductSyncStats {
  final int total;
  final int synced;
  final int pendingSync;
  final DateTime? oldestPendingChange;

  ProductSyncStats({
    required this.total,
    required this.synced,
    required this.pendingSync,
    this.oldestPendingChange,
  });

  bool get hasPendingChanges => pendingSync > 0;
}
