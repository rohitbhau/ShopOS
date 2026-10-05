import 'package:flutter/foundation.dart';
// Sync service - handles push/pull operations between local DB and Supabase
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import 'package:uuid/uuid.dart';

class SyncService {
  final AppDatabase _db;
  final SupabaseClient _supabase;
  bool _isSyncing = false;

  SyncService(this._db, this._supabase);

  bool get isSyncing => _isSyncing;

  // Full sync: pull from server, push local changes
  Future<SyncResult> sync(String tenantId) async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    final result = SyncResult(success: true, message: 'Sync completed');

    try {
      // Step 1: Push local changes (outbox first, then dirty records)
      await _pushOutboxItems();
      await _pushDirtyRecords(tenantId);

      // Step 2: Pull server changes
      await _pullProducts(tenantId);
      await _pullCustomers(tenantId);
      await _pullInvoices(tenantId);

      // Step 3: Update last sync time
      await _db.setLastSyncTime(DateTime.now());

      result.pulledProducts = result.pulledProducts;
      result.pulledCustomers = result.pulledCustomers;
      result.pulledInvoices = result.pulledInvoices;
      result.pushedChanges = result.pushedChanges;
    } catch (e) {
      result.success = false;
      result.message = 'Sync failed: $e';
      result.error = e.toString();
    } finally {
      _isSyncing = false;
    }

    return result;
  }

  // Push outbox items (queued operations)
  Future<void> _pushOutboxItems() async {
    final items = await _db.getPendingOutboxItems();

    for (final item in items) {
      try {
        final data = jsonDecode(item.dataJson) as Map<String, dynamic>;

        switch (item.operation) {
          case 'insert':
            await _supabase.from(item.targetTable).insert(data);
            break;
          case 'update':
            await _supabase
                .from(item.targetTable)
                .update(data)
                .eq('id', item.recordId);
            break;
          case 'delete':
            await _supabase
                .from(item.targetTable)
                .delete()
                .eq('id', item.recordId);
            break;
        }

        // Remove from outbox on success
        await _db.deleteOutboxItem(item.id);
      } catch (e) {
        // Update retry count and error message
        await _db.updateOutboxItemRetry(item.id, e.toString());
        
        // Skip items with more than 5 retries
        if (item.retryCount >= 5) {
          debugPrint('Outbox item ${item.id} failed after 5 retries: $e');
        }
      }
    }
  }

  // Push dirty products
  Future<void> _pushDirtyRecords(String tenantId) async {
    // Push products
    final dirtyProducts = await _db.getDirtyProducts(tenantId);
    for (final product in dirtyProducts) {
      try {
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

        // Get entity_id for product
        final entityResponse = await _supabase
            .from('entities')
            .select('id')
            .eq('name', 'product')
            .single();

        await _supabase.from('records').upsert({
          ...data,
          'entity_id': entityResponse['id'],
        });

        // Mark as synced
        await _db.updateProduct(product.copyWith(
          isDirty: false,
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('Failed to push product ${product.id}: $e');
      }
    }

    // Push customers
    final dirtyCustomers = await _db.getDirtyCustomers(tenantId);
    for (final customer in dirtyCustomers) {
      try {
        final data = {
          'id': customer.id,
          'tenant_id': customer.tenantId,
          'data': {
            'name': customer.name,
            'phone': customer.phone,
            'email': customer.email,
            'address': customer.address,
            'outstanding': customer.outstanding,
          },
          'updated_at': customer.updatedAt.toIso8601String(),
        };

        final entityResponse = await _supabase
            .from('entities')
            .select('id')
            .eq('name', 'customer')
            .single();

        await _supabase.from('records').upsert({
          ...data,
          'entity_id': entityResponse['id'],
        });

        await _db.updateCustomer(customer.copyWith(
          isDirty: false,
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('Failed to push customer ${customer.id}: $e');
      }
    }

    // Push invoices
    final dirtyInvoices = await _db.getDirtyInvoices(tenantId);
    for (final invoice in dirtyInvoices) {
      try {
        final items = jsonDecode(invoice.itemsJson) as List;
        final data = {
          'id': invoice.id,
          'tenant_id': invoice.tenantId,
          'data': {
            'invoice_number': invoice.invoiceNumber,
            'invoice_date': invoice.invoiceDate.toIso8601String(),
            'customer_id': invoice.customerId,
            'customer_name': invoice.customerName,
            'items': items,
            'subtotal': invoice.subtotal,
            'tax_amount': invoice.taxAmount,
            'total': invoice.total,
            'payment_mode': invoice.paymentMode,
            'payment_status': invoice.paymentStatus,
          },
          'updated_at': invoice.updatedAt.toIso8601String(),
        };

        final entityResponse = await _supabase
            .from('entities')
            .select('id')
            .eq('name', 'invoice')
            .single();

        await _supabase.from('records').upsert({
          ...data,
          'entity_id': entityResponse['id'],
        });

        await _db.updateInvoice(invoice.copyWith(
          isDirty: false,
          lastSyncedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('Failed to push invoice ${invoice.id}: $e');
      }
    }
  }

  // Pull products from server
  Future<void> _pullProducts(String tenantId) async {
    final lastSync = await _db.getLastSyncTime();

    final entityResponse = await _supabase
        .from('entities')
        .select('id')
        .eq('name', 'product')
        .single();

    final entityId = entityResponse['id'];

    var query = _supabase
        .from('records')
        .select()
        .eq('tenant_id', tenantId)
        .eq('entity_id', entityId)
        .isFilter('deleted_at', null);

    // Only pull changes since last sync if available
    if (lastSync != null) {
      query = query.gte('updated_at', lastSync.toIso8601String());
    }

    final response = await query;
    final records = List<Map<String, dynamic>>.from(response);

    for (final record in records) {
      final data = record['data'] as Map<String, dynamic>;
      final product = Product(
        id: record['id'],
        tenantId: record['tenant_id'],
        name: data['name'] ?? '',
        sku: data['sku'],
        price: (data['price'] ?? 0).toDouble(),
        cost: data['cost'] != null ? (data['cost'] as num).toDouble() : null,
        stock: data['stock'] ?? 0,
        minStock: data['min_stock'],
        category: data['category'],
        unit: data['unit'],
        gstRate: (data['gst_rate'] ?? 18).toDouble(),
        isActive: data['is_active'] ?? true,
        createdAt: DateTime.parse(record['created_at']),
        updatedAt: DateTime.parse(record['updated_at']),
        lastSyncedAt: DateTime.now(),
        isDirty: false,
      );

      await _db.into(_db.products).insertOnConflictUpdate(product);
    }
  }

  // Pull customers from server
  Future<void> _pullCustomers(String tenantId) async {
    final lastSync = await _db.getLastSyncTime();

    final entityResponse = await _supabase
        .from('entities')
        .select('id')
        .eq('name', 'customer')
        .single();

    final entityId = entityResponse['id'];

    var query = _supabase
        .from('records')
        .select()
        .eq('tenant_id', tenantId)
        .eq('entity_id', entityId)
        .isFilter('deleted_at', null);

    if (lastSync != null) {
      query = query.gte('updated_at', lastSync.toIso8601String());
    }

    final response = await query;
    final records = List<Map<String, dynamic>>.from(response);

    for (final record in records) {
      final data = record['data'] as Map<String, dynamic>;
      final customer = Customer(
        id: record['id'],
        tenantId: record['tenant_id'],
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        email: data['email'],
        address: data['address'],
        outstanding: (data['outstanding'] ?? 0).toDouble(),
        createdAt: DateTime.parse(record['created_at']),
        updatedAt: DateTime.parse(record['updated_at']),
        lastSyncedAt: DateTime.now(),
        isDirty: false,
      );

      await _db.into(_db.customers).insertOnConflictUpdate(customer);

      // Pull ledger entries for this customer
      final ledger = data['ledger'] as List?;
      if (ledger != null) {
        for (final entry in ledger) {
          final ledgerEntry = LedgerEntry(
            id: const Uuid().v4(),
            customerId: customer.id,
            date: DateTime.parse(entry['date']),
            type: entry['type'],
            invoiceNumber: entry['invoice_number'],
            description: entry['description'] ?? '',
            debit: (entry['debit'] ?? 0).toDouble(),
            credit: (entry['credit'] ?? 0).toDouble(),
            balance: (entry['balance'] ?? 0).toDouble(),
            createdAt: DateTime.now(),
            isDirty: false,
          );

          await _db.into(_db.ledgerEntries).insertOnConflictUpdate(ledgerEntry);
        }
      }
    }
  }

  // Pull invoices from server
  Future<void> _pullInvoices(String tenantId) async {
    final lastSync = await _db.getLastSyncTime();

    final entityResponse = await _supabase
        .from('entities')
        .select('id')
        .eq('name', 'invoice')
        .single();

    final entityId = entityResponse['id'];

    var query = _supabase
        .from('records')
        .select()
        .eq('tenant_id', tenantId)
        .eq('entity_id', entityId)
        .isFilter('deleted_at', null);

    if (lastSync != null) {
      query = query.gte('updated_at', lastSync.toIso8601String());
    }

    final response = await query;
    final records = List<Map<String, dynamic>>.from(response);

    for (final record in records) {
      final data = record['data'] as Map<String, dynamic>;
      final invoice = Invoice(
        id: record['id'],
        tenantId: record['tenant_id'],
        invoiceNumber: data['invoice_number'] ?? '',
        invoiceDate: DateTime.parse(data['invoice_date']),
        customerId: data['customer_id'],
        customerName: data['customer_name'],
        subtotal: (data['subtotal'] ?? 0).toDouble(),
        taxAmount: (data['tax_amount'] ?? 0).toDouble(),
        total: (data['total'] ?? 0).toDouble(),
        paymentMode: data['payment_mode'] ?? 'cash',
        paymentStatus: data['payment_status'] ?? 'paid',
        itemsJson: jsonEncode(data['items'] ?? []),
        createdAt: DateTime.parse(record['created_at']),
        updatedAt: DateTime.parse(record['updated_at']),
        lastSyncedAt: DateTime.now(),
        isDirty: false,
      );

      await _db.into(_db.invoices).insertOnConflictUpdate(invoice);
    }
  }

  // Queue an operation for later sync (when offline)
  Future<void> queueOperation(
    String operation,
    String tableName,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    final item = OutboxQueueData(
      id: 0, // Auto-increment
      operation: operation,
      targetTable: tableName,
      recordId: recordId,
      dataJson: jsonEncode(data),
      retryCount: 0,
      createdAt: DateTime.now(),
      lastAttemptAt: null,
      errorMessage: null,
    );

    await _db.insertOutboxItem(item);
  }

  // Clear old processed items from outbox
  Future<void> cleanupOutbox() async {
    await _db.clearProcessedOutboxItems();
  }
}

class SyncResult {
  bool success;
  String message;
  String? error;
  int pulledProducts = 0;
  int pulledCustomers = 0;
  int pulledInvoices = 0;
  int pushedChanges = 0;

  SyncResult({
    required this.success,
    required this.message,
    this.error,
  });
}
