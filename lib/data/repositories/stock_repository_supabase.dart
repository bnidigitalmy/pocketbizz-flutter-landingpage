import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stock_item.dart';
import '../models/stock_movement.dart';
import '../models/stock_item_batch.dart';

/// Stock Repository for managing stock items and movements
class StockRepository {
  final SupabaseClient _supabase;

  StockRepository(this._supabase);

  // ============================================================================
  // STOCK ITEMS CRUD
  // ============================================================================

  /// Get all stock items for current user
  Future<List<StockItem>> getAllStockItems({bool includeArchived = false}) async {
    try {
      dynamic query = _supabase
          .from('stock_items')
          .select();

      if (!includeArchived) {
        query = query.eq('is_archived', false);
      }

      query = query.order('name', ascending: true);

      final response = await query;
      return (response as List).map((json) => StockItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch stock items: $e');
    }
  }

  /// Get low stock items (quantity <= threshold)
  Future<List<StockItem>> getLowStockItems() async {
    try {
      // Use the view we created in migration, or fallback to manual calculation
      try {
        final response = await _supabase
            .from('low_stock_items')
            .select()
            .order('stock_level_percentage', ascending: true);

        if (response != null && response is List) {
          return (response as List)
              .map((json) {
                try {
                  return StockItem.fromJson(json);
                } catch (e) {
                  debugPrint('Error parsing stock item: $e, json: $json');
                  return null;
                }
              })
              .whereType<StockItem>()
              .toList();
        }
      } catch (viewError) {
        // If view doesn't exist, fallback to manual calculation
        debugPrint('low_stock_items view not available, using manual calculation: $viewError');
      }

      // Fallback: Get all items and filter manually
      final allItems = await getAllStockItems();
      return allItems.where((item) => item.isLowStock).toList();
    } catch (e) {
      debugPrint('Error in getLowStockItems: $e');
      // Return empty list instead of throwing to prevent UI crash
      return [];
    }
  }

  /// Get stock item by ID
  Future<StockItem?> getStockItemById(String id) async {
    try {
      final response = await _supabase
          .from('stock_items')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? StockItem.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch stock item: $e');
    }
  }

  /// Search stock items by name
  Future<List<StockItem>> searchStockItems(String query) async {
    try {
      final response = await _supabase
          .from('stock_items')
          .select()
          .ilike('name', '%$query%')
          .eq('is_archived', false)
          .order('name', ascending: true);

      return (response as List).map((json) => StockItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search stock items: $e');
    }
  }

  /// Create new stock item
  Future<StockItem> createStockItem(StockItemInput input) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final data = {
        ...input.toJson(),
        'business_owner_id': userId,
        'current_quantity': 0.0, // Start with 0, use recordStockMovement to add initial stock
      };

      final response = await _supabase
          .from('stock_items')
          .insert(data)
          .select()
          .single();

      return StockItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create stock item: $e');
    }
  }

  /// Update stock item
  Future<StockItem> updateStockItem(String id, StockItemInput input) async {
    try {
      final data = {
        ...input.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('stock_items')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return StockItem.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update stock item: $e');
    }
  }

  /// Archive stock item (soft delete)
  Future<void> archiveStockItem(String id) async {
    try {
      await _supabase
          .from('stock_items')
          .update({
            'is_archived': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to archive stock item: $e');
    }
  }

  /// Delete stock item (hard delete)
  Future<void> deleteStockItem(String id) async {
    try {
      await _supabase.from('stock_items').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete stock item: $e');
    }
  }

  // ============================================================================
  // STOCK MOVEMENTS
  // ============================================================================

  /// Record a stock movement (uses DB function for consistency)
  /// This is the THREAD-SAFE way to update stock quantities
  Future<String> recordStockMovement(StockMovementInput input) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      final params = {
        ...input.toJson(),
        'p_created_by': userId,
      };

      final response = await _supabase.rpc('record_stock_movement', params: params);

      // Response is the movement ID
      return response as String;
    } catch (e) {
      throw Exception('Failed to record stock movement: $e');
    }
  }

  /// Get stock movements for a specific stock item
  Future<List<StockMovement>> getStockMovements(
    String stockItemId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('stock_movements')
          .select()
          .eq('stock_item_id', stockItemId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).map((json) => StockMovement.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch stock movements: $e');
    }
  }

  /// Get all stock movements for current user
  Future<List<StockMovement>> getAllStockMovements({
    StockMovementType? type,
    int limit = 100,
  }) async {
    try {
      dynamic query = _supabase
          .from('stock_movements')
          .select();

      if (type != null) {
        query = query.eq('movement_type', type.value);
      }

      query = query.order('created_at', ascending: false).limit(limit);

      final response = await query;
      return (response as List).map((json) => StockMovement.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch stock movements: $e');
    }
  }

  // ============================================================================
  // CONVENIENCE METHODS
  // ============================================================================

  /// Add stock (purchase or replenish)
  Future<void> addStock({
    required String stockItemId,
    required double quantity,
    required String reason,
    bool isPurchase = false,
  }) async {
    await recordStockMovement(
      StockMovementInput(
        stockItemId: stockItemId,
        movementType: isPurchase 
            ? StockMovementType.purchase 
            : StockMovementType.replenish,
        quantityChange: quantity,
        reason: reason,
      ),
    );
  }

  /// Remove stock (waste, production use, etc)
  Future<void> removeStock({
    required String stockItemId,
    required double quantity,
    required StockMovementType type,
    required String reason,
    String? referenceId,
    String? referenceType,
  }) async {
    await recordStockMovement(
      StockMovementInput(
        stockItemId: stockItemId,
        movementType: type,
        quantityChange: -quantity, // Negative for removal
        reason: reason,
        referenceId: referenceId,
        referenceType: referenceType,
      ),
    );
  }

  /// Adjust stock quantity (manual correction)
  Future<void> adjustStock({
    required String stockItemId,
    required double quantityChange,
    required String reason,
  }) async {
    await recordStockMovement(
      StockMovementInput(
        stockItemId: stockItemId,
        movementType: StockMovementType.adjust,
        quantityChange: quantityChange,
        reason: reason,
      ),
    );
  }

  // ============================================================================
  // BULK IMPORT
  // ============================================================================

  /// Bulk import stock items from parsed data
  /// Returns summary dengan success/failure counts
  Future<Map<String, dynamic>> bulkImportStockItems(
    List<Map<String, dynamic>> items, {
    bool skipDuplicates = true,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      int successCount = 0;
      int failureCount = 0;
      final List<String> errors = [];

      // Get existing items untuk check duplicates
      final existingItems = await getAllStockItems();
      final existingNames = existingItems.map((item) => item.name.toLowerCase()).toSet();

      // Prepare batch insert data
      final List<Map<String, dynamic>> itemsToInsert = [];
      final List<Map<String, dynamic>> movementsToRecord = [];

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final rowNum = i + 2; // +2 for header row and 0-index

        try {
          // Validate required fields
          if (item['name'] == null || item['name'].toString().trim().isEmpty) {
            errors.add('Row $rowNum: Item Name diperlukan');
            failureCount++;
            continue;
          }

          final name = item['name'].toString().trim();
          final unit = item['unit']?.toString().trim() ?? 'pcs';
          final packageSize = (item['packageSize'] as num?)?.toDouble() ?? 1.0;
          final purchasePrice = (item['purchasePrice'] as num?)?.toDouble() ?? 0.0;
          final currentQuantity = (item['currentQuantity'] as num?)?.toDouble() ?? 0.0;
          final lowStockThreshold = (item['lowStockThreshold'] as num?)?.toDouble() ?? 5.0;
          final notes = item['notes']?.toString().trim();

          // Check for duplicates
          if (skipDuplicates && existingNames.contains(name.toLowerCase())) {
            errors.add('Row $rowNum: "$name" already exists (skipped)');
            failureCount++;
            continue;
          }

          // Prepare stock item data
          final stockItemData = {
            'business_owner_id': userId,
            'name': name,
            'unit': unit,
            'package_size': packageSize,
            'purchase_price': purchasePrice,
            'current_quantity': 0.0, // Will be set via movement if quantity > 0
            'low_stock_threshold': lowStockThreshold,
            'notes': notes,
            'is_archived': false,
            'version': 0,
          };

          itemsToInsert.add(stockItemData);

          // If initial quantity provided, prepare movement
          if (currentQuantity > 0) {
            movementsToRecord.add({
              'name': name,
              'quantity': currentQuantity,
              'reason': 'Imported from file',
            });
          }

          successCount++;
        } catch (e) {
          errors.add('Row $rowNum: Error processing item - $e');
          failureCount++;
        }
      }

      // Batch insert stock items
      if (itemsToInsert.isNotEmpty) {
        final response = await _supabase
            .from('stock_items')
            .insert(itemsToInsert)
            .select();

        // Record initial stock movements if needed
        if (movementsToRecord.isNotEmpty && response != null) {
          final insertedItems = (response as List).map((json) => StockItem.fromJson(json)).toList();
          
          // Create map of name to ID
          final nameToId = <String, String>{};
          for (final item in insertedItems) {
            nameToId[item.name.toLowerCase()] = item.id;
          }

          // Record movements
          for (final movement in movementsToRecord) {
            final itemId = nameToId[movement['name'].toString().toLowerCase()];
            if (itemId != null) {
              try {
                await recordStockMovement(
                  StockMovementInput(
                    stockItemId: itemId,
                    movementType: StockMovementType.purchase,
                    quantityChange: (movement['quantity'] as num).toDouble(),
                    reason: movement['reason'] as String,
                  ),
                );
              } catch (e) {
                errors.add('Failed to record initial stock for "${movement['name']}": $e');
              }
            }
          }
        }
      }

      return {
        'success': true,
        'successCount': successCount,
        'failureCount': failureCount,
        'totalCount': items.length,
        'errors': errors,
      };
    } catch (e) {
      throw Exception('Failed to bulk import stock items: $e');
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get stock statistics
  Future<Map<String, dynamic>> getStockStatistics() async {
    try {
      final items = await getAllStockItems();
      final lowStockItems = items.where((item) => item.isLowStock).toList();

      final totalValue = items.fold<double>(
        0.0,
        (sum, item) => sum + (item.currentQuantity * item.costPerUnit),
      );

      return {
        'total_items': items.length,
        'low_stock_count': lowStockItems.length,
        'total_inventory_value': totalValue,
        'out_of_stock_count': items.where((item) => item.currentQuantity <= 0).length,
      };
    } catch (e) {
      throw Exception('Failed to get stock statistics: $e');
    }
  }

  // ============================================================================
  // STOCK ITEM BATCHES
  // ============================================================================

  /// Get all batches for a stock item
  Future<List<StockItemBatch>> getStockItemBatches(String stockItemId) async {
    try {
      final response = await _supabase
          .from('stock_item_batches')
          .select()
          .eq('stock_item_id', stockItemId)
          .order('purchase_date', ascending: true)
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((json) => StockItemBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch stock item batches: $e');
    }
  }

  /// Get batch summary for a stock item
  Future<Map<String, dynamic>> getBatchSummary(String stockItemId) async {
    try {
      final response = await _supabase
          .from('stock_item_batches_summary')
          .select()
          .eq('stock_item_id', stockItemId)
          .maybeSingle();

      if (response == null) {
        return {
          'total_batches': 0,
          'total_quantity': 0.0,
          'total_remaining': 0.0,
          'earliest_expiry': null,
          'expired_batches': 0,
          'active_batches': 0,
        };
      }

      return {
        'total_batches': response['total_batches'] ?? 0,
        'total_quantity': (response['total_quantity'] as num?)?.toDouble() ?? 0.0,
        'total_remaining': (response['total_remaining'] as num?)?.toDouble() ?? 0.0,
        'earliest_expiry': response['earliest_expiry'] != null
            ? DateTime.parse(response['earliest_expiry'] as String)
            : null,
        'expired_batches': response['expired_batches'] ?? 0,
        'active_batches': response['active_batches'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error getting batch summary: $e');
      // Return default if view doesn't exist
      return {
        'total_batches': 0,
        'total_quantity': 0.0,
        'total_remaining': 0.0,
        'earliest_expiry': null,
        'expired_batches': 0,
        'active_batches': 0,
      };
    }
  }

  /// Create a new stock item batch
  Future<String> createStockItemBatch(StockItemBatchInput input) async {
    try {
      final response = await _supabase.rpc(
        'record_stock_item_batch',
        params: input.toJson(),
      );

      return response as String;
    } catch (e) {
      throw Exception('Failed to create stock item batch: $e');
    }
  }

  /// Get batches with expiry alerts (expired or expiring soon)
  Future<List<StockItemBatch>> getExpiringBatches({int daysAhead = 7}) async {
    try {
      final cutoffDate = DateTime.now().add(Duration(days: daysAhead));
      
      final response = await _supabase
          .from('stock_item_batches')
          .select()
          .not('expiry_date', 'is', null)
          .lte('expiry_date', cutoffDate.toIso8601String().split('T')[0])
          .gt('remaining_qty', 0)
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((json) => StockItemBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch expiring batches: $e');
    }
  }
}

