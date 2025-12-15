import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/production_batch.dart';
import '../models/production_preview.dart';
import '../models/bulk_production_preview.dart';
import '../../core/utils/unit_conversion.dart';
import 'recipes_repository_supabase.dart';
import 'stock_repository_supabase.dart';

/// Production Repository for managing production batches
class ProductionRepository {
  final SupabaseClient _supabase;

  ProductionRepository(this._supabase);

  /// Map reference types (eg: 'delivery') to valid movement types stored in DB.
  /// We keep `movement_type` constrained and use `reference_type` to distinguish sources.
  String _movementTypeForReference(String? referenceType) {
    switch ((referenceType ?? '').toLowerCase()) {
      case 'adjustment':
        return 'adjustment';
      case 'expired':
        return 'expired';
      case 'damaged':
        return 'damaged';
      case 'production':
        return 'production';
      case 'sale':
      case 'delivery':
      default:
        return 'sale';
    }
  }

  // ============================================================================
  // PRODUCTION BATCHES CRUD
  // ============================================================================

  /// Get all production batches
  Future<List<ProductionBatch>> getAllBatches({
    String? productId,
    bool onlyWithRemaining = false,
  }) async {
    try {
      dynamic query = _supabase
          .from('production_batches')
          .select('''
            *,
            products!inner(name)
          ''');

      if (productId != null) {
        query = query.eq('product_id', productId);
      }

      if (onlyWithRemaining) {
        query = query.gt('remaining_qty', 0);
      }

      query = query.order('batch_date', ascending: false);

      final response = await query;
      return (response as List).map((json) {
        // Extract product_name from joined products table
        final productData = json['products'];
        if (productData != null && productData is Map) {
          json['product_name'] = productData['name'];
        }
        return ProductionBatch.fromJson(json);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch production batches: $e');
    }
  }

  /// Get batch by ID
  Future<ProductionBatch?> getBatchById(String id) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? ProductionBatch.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch production batch: $e');
    }
  }

  /// Get recent batches (last N)
  Future<List<ProductionBatch>> getRecentBatches({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent batches: $e');
    }
  }

  /// Get batches by date range
  Future<List<ProductionBatch>> getBatchesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .gte('batch_date', startDate.toIso8601String().split('T')[0])
          .lte('batch_date', endDate.toIso8601String().split('T')[0])
          .order('batch_date', ascending: false);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch batches by date range: $e');
    }
  }

  /// Record production batch (uses DB function - auto-deducts stock!)
  Future<String> recordProductionBatch(ProductionBatchInput input) async {
    try {
      // Build params, only include non-null optional fields
      final params = <String, dynamic>{
        'p_product_id': input.productId,
        'p_quantity': input.quantity,
        'p_batch_date': input.batchDate.toIso8601String().split('T')[0],
      };
      
      // Add optional fields only if they have values
      if (input.expiryDate != null) {
        params['p_expiry_date'] = input.expiryDate!.toIso8601String().split('T')[0];
      }
      if (input.notes != null && input.notes!.isNotEmpty) {
        params['p_notes'] = input.notes;
      }
      if (input.batchNumber != null && input.batchNumber!.isNotEmpty) {
        params['p_batch_number'] = input.batchNumber;
      }

      // Debug: Print params being sent
      print('🔍 Calling record_production_batch with params: $params');

      final response = await _supabase.rpc(
        'record_production_batch',
        params: params,
      );

      // Response is the batch ID
      return response as String;
    } catch (e) {
      // Provide more detailed error message
      final errorMsg = e.toString();
      print('❌ Error calling record_production_batch: $errorMsg');
      
      if (errorMsg.contains('does not exist') || errorMsg.contains('404')) {
        throw Exception(
          'Function record_production_batch not found. Please apply migration: db/migrations/create_record_production_batch_function.sql'
        );
      }
      
      // Check for 400 Bad Request - might be parameter mismatch
      if (errorMsg.contains('400') || errorMsg.contains('Bad Request')) {
        throw Exception(
          'Bad Request (400): Function exists but parameters may be incorrect. '
          'Please check: 1) Function is applied correctly, 2) Product ID is valid UUID, '
          '3) Quantity is integer, 4) Dates are in YYYY-MM-DD format. '
          'Error: $errorMsg'
        );
      }
      
      throw Exception('Failed to record production batch: $e');
    }
  }

  /// Update batch (for corrections, not for stock deduction)
  Future<ProductionBatch> updateBatch(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final data = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('production_batches')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return ProductionBatch.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update production batch: $e');
    }
  }

  /// Update remaining quantity (used when selling from batch)
  Future<void> updateRemainingQty(String id, double newRemainingQty) async {
    try {
      await _supabase
          .from('production_batches')
          .update({
            'remaining_qty': newRemainingQty,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update remaining quantity: $e');
    }
  }

  /// Delete batch (hard delete - use carefully!)
  Future<void> deleteBatch(String id) async {
    try {
      await _supabase.from('production_batches').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete production batch: $e');
    }
  }

  // ============================================================================
  // FIFO OPERATIONS
  // ============================================================================

  /// Get oldest batches with remaining qty (for FIFO sales)
  Future<List<ProductionBatch>> getOldestBatchesForProduct(
    String productId, {
    int limit = 5,
  }) async {
    try {
      final response = await _supabase
          .from('production_batches')
          .select()
          .eq('product_id', productId)
          .gt('remaining_qty', 0)
          .order('batch_date', ascending: true) // Oldest first
          .limit(limit);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch oldest batches: $e');
    }
  }

  /// Deduct quantity from batch (FIFO)
  /// Returns remaining quantity to deduct if batch is fully consumed
  /// [referenceId] and [referenceType] are optional for tracking purposes
  Future<double> deductFromBatch(
    String batchId,
    double quantity, {
    String? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    try {
      final batch = await getBatchById(batchId);
      if (batch == null) {
        throw Exception('Batch not found');
      }

      final newRemaining = batch.remainingQty - quantity;

      if (newRemaining < 0) {
        // Batch fully consumed, return excess quantity
        await updateRemainingQty(batchId, 0);
        // Log movement
        await _logStockMovement(
          batchId: batchId,
          productId: batch.productId,
          movementType: _movementTypeForReference(referenceType),
          quantity: batch.remainingQty, // Deduct all remaining
          remainingAfter: 0,
          referenceId: referenceId,
          referenceType: referenceType,
          notes: notes,
        );
        return -newRemaining; // Return positive excess
      } else {
        // Batch partially consumed
        await updateRemainingQty(batchId, newRemaining);
        // Log movement
        await _logStockMovement(
          batchId: batchId,
          productId: batch.productId,
          movementType: _movementTypeForReference(referenceType),
          quantity: quantity,
          remainingAfter: newRemaining,
          referenceId: referenceId,
          referenceType: referenceType,
          notes: notes,
        );
        return 0; // No excess
      }
    } catch (e) {
      throw Exception('Failed to deduct from batch: $e');
    }
  }

  /// Log stock movement for tracking
  Future<void> _logStockMovement({
    required String batchId,
    required String productId,
    required String movementType,
    required double quantity,
    required double remainingAfter,
    String? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('production_batch_stock_movements').insert({
        'business_owner_id': userId,
        'batch_id': batchId,
        'product_id': productId,
        'movement_type': movementType,
        'quantity': quantity,
        'remaining_after_movement': remainingAfter,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'notes': notes,
      });
    } catch (e) {
      // Log error but don't fail the deduction
      print('Warning: Failed to log stock movement: $e');
    }
  }

  /// Deduct quantity using FIFO (from oldest to newest)
  /// [referenceId] and [referenceType] are optional for tracking purposes
  Future<List<Map<String, dynamic>>> deductFIFO(
    String productId,
    double quantityToDeduct, {
    String? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    try {
      final batches = await getOldestBatchesForProduct(productId);
      final deductions = <Map<String, dynamic>>[];
      double remaining = quantityToDeduct;

      for (final batch in batches) {
        if (remaining <= 0) break;

        final deductedFromThis = remaining.clamp(0.0, batch.remainingQty);
        final excess = await deductFromBatch(
          batch.id,
          deductedFromThis,
          referenceId: referenceId,
          referenceType: referenceType,
          notes: notes,
        );

        deductions.add({
          'batch_id': batch.id,
          'quantity_deducted': deductedFromThis,
          'cost_per_unit': batch.costPerUnit,
          'total_cost': deductedFromThis * batch.costPerUnit,
        });

        remaining = excess;
      }

      if (remaining > 0) {
        throw Exception(
          'Insufficient stock in batches. Remaining: $remaining',
        );
      }

      return deductions;
    } catch (e) {
      throw Exception('Failed to deduct FIFO: $e');
    }
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  /// Get production statistics
  Future<Map<String, dynamic>> getProductionStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      dynamic query = _supabase.from('production_batches').select();

      if (startDate != null) {
        query = query.gte('batch_date', startDate.toIso8601String().split('T')[0]);
      }

      if (endDate != null) {
        query = query.lte('batch_date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query;
      final batches = (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();

      final totalBatches = batches.length;
      final totalUnitsProduced = batches.fold<int>(
        0,
        (sum, batch) => sum + batch.quantity,
      );
      final totalCost = batches.fold<double>(
        0.0,
        (sum, batch) => sum + batch.totalCost,
      );
      final totalRemaining = batches.fold<double>(
        0.0,
        (sum, batch) => sum + batch.remainingQty,
      );
      final expiredBatches = batches.where((b) => b.isExpired).length;

      return {
        'total_batches': totalBatches,
        'total_units_produced': totalUnitsProduced,
        'total_cost': totalCost,
        'total_remaining': totalRemaining,
        'expired_batches': expiredBatches,
        'avg_cost_per_batch':
            totalBatches > 0 ? totalCost / totalBatches : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get production statistics: $e');
    }
  }

  /// Get total remaining units for a product
  Future<double> getTotalRemainingForProduct(String productId) async {
    try {
      final batches = await getAllBatches(
        productId: productId,
        onlyWithRemaining: true,
      );

      return batches.fold<double>(
        0.0,
        (sum, batch) => sum + batch.remainingQty,
      );
    } catch (e) {
      throw Exception('Failed to get total remaining: $e');
    }
  }

  /// Consume stock from production batches using FIFO
  /// Returns list of batch updates with consumed quantities
  Future<List<Map<String, dynamic>>> consumeStock({
    required String productId,
    required double quantity,
    String? deliveryId,
    String? note,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get batches ordered by batch_date (FIFO - oldest first)
      // NOTE: getAllBatches sorts newest first, so we must use FIFO helper here.
      final batches = await getOldestBatchesForProduct(productId, limit: 500);

      if (batches.isEmpty) {
        throw Exception('No stock available for product');
      }

      // Calculate total available
      final totalAvailable = batches.fold<double>(
        0.0,
        (sum, batch) => sum + batch.remainingQty,
      );

      if (totalAvailable < quantity) {
        throw Exception(
          'Insufficient stock. Available: $totalAvailable, Required: $quantity'
        );
      }

      // Consume from batches using FIFO
      double remainingToConsume = quantity;
      final updates = <Map<String, dynamic>>[];

      for (final batch in batches) {
        if (remainingToConsume <= 0) break;

        final available = batch.remainingQty;
        if (available <= 0) continue;

        final toConsume = available < remainingToConsume 
            ? available 
            : remainingToConsume;
        
        final newRemaining = available - toConsume;
        remainingToConsume -= toConsume;

        // Update batch
        await _supabase
            .from('production_batches')
            .update({
              'remaining_qty': newRemaining,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', batch.id);

        // Log stock movement for tracking
        await _logStockMovement(
          batchId: batch.id,
          productId: productId,
          movementType: _movementTypeForReference('delivery'),
          quantity: toConsume,
          remainingAfter: newRemaining,
          referenceId: deliveryId,
          referenceType: 'delivery',
          notes: note,
        );

        updates.add({
          'batchId': batch.id,
          'consumed': toConsume,
          'remaining': newRemaining,
        });
      }

      return updates;
    } catch (e) {
      throw Exception('Failed to consume stock: $e');
    }
  }

  /// Get expired batches
  Future<List<ProductionBatch>> getExpiredBatches() async {
    try {
      final now = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('production_batches')
          .select()
          .not('expiry_date', 'is', null)
          .lt('expiry_date', now)
          .gt('remaining_qty', 0)
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((json) => ProductionBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch expired batches: $e');
    }
  }

  // ============================================================================
  // PRODUCTION PLANNING & PREVIEW
  // ============================================================================

  /// Preview production plan - Calculate materials needed and check stock
  Future<ProductionPlan> previewProductionPlan({
    required String productId,
    required int quantity, // Number of batches
  }) async {
    try {
      // Get product info
      final productResponse = await _supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      final product = productResponse;
      final unitsPerBatch = product['units_per_batch'] ?? 1;
      final totalCostPerBatch = product['total_cost_per_batch'] ?? 0.0;

      // Get active recipe
      final recipesRepo = RecipesRepositorySupabase();
      final recipe = await recipesRepo.getActiveRecipe(productId);

      if (recipe == null) {
        throw Exception('No active recipe found for this product');
      }

      // Get recipe items
      final recipeItems = await recipesRepo.getRecipeItems(recipe.id);

      // Get all stock items
      final stockRepo = StockRepository(_supabase);
      final stockItems = await stockRepo.getAllStockItems();

      // Calculate materials needed
      final materialsNeeded = <MaterialPreview>[];
      bool allStockSufficient = true;
      double totalProductionCost = 0.0;

      for (final recipeItem in recipeItems) {
        // Find stock item
        final stockItem = stockItems.firstWhere(
          (s) => s.id == recipeItem.stockItemId,
          orElse: () => throw Exception(
            'Stock item ${recipeItem.stockItemId} not found',
          ),
        );

        // Calculate quantity needed for all batches
        final quantityNeededPerBatch = recipeItem.quantityNeeded;
        final totalQuantityNeeded = quantityNeededPerBatch * quantity;

        // Convert to stock unit
        final convertedQuantity = UnitConversion.convert(
          quantity: totalQuantityNeeded,
          fromUnit: recipeItem.usageUnit,
          toUnit: stockItem.unit,
        );

        // Check sufficiency
        final isSufficient = stockItem.currentQuantity >= convertedQuantity;
        final shortage = isSufficient
            ? 0.0
            : convertedQuantity - stockItem.currentQuantity;

        // Calculate packages needed (rounded up to nearest pek/pcs)
        final packageSize = stockItem.packageSize > 0 ? stockItem.packageSize : 1.0;
        final packagesNeeded = isSufficient ? 0 : (shortage / packageSize).ceil();

        if (!isSufficient) {
          allStockSufficient = false;
        }

        materialsNeeded.add(
          MaterialPreview(
            stockItemId: stockItem.id,
            stockItemName: stockItem.name,
            quantityNeeded: totalQuantityNeeded,
            usageUnit: recipeItem.usageUnit,
            currentStock: stockItem.currentQuantity,
            stockUnit: stockItem.unit,
            isSufficient: isSufficient,
            shortage: shortage,
            convertedQuantity: convertedQuantity,
            packageSize: packageSize,
            packagesNeeded: packagesNeeded,
          ),
        );
      }

      // Calculate total production cost
      totalProductionCost = (totalCostPerBatch as num).toDouble() * quantity;

      return ProductionPlan(
        product: ProductInfo(
          id: productId,
          name: product['name'] ?? 'Unknown',
          unitsPerBatch: unitsPerBatch,
          totalCostPerBatch: totalCostPerBatch.toStringAsFixed(2),
        ),
        quantity: quantity,
        totalUnits: (quantity * unitsPerBatch).toInt(),
        materialsNeeded: materialsNeeded,
        allStockSufficient: allStockSufficient,
        totalProductionCost: totalProductionCost,
      );
    } catch (e) {
      throw Exception('Failed to preview production plan: $e');
    }
  }

  /// Bulk preview production plan for multiple products.
  /// - Aggregates raw material needs across all selected products.
  /// - Computes a "produce now" plan (partial) that respects shared raw materials:
  ///   products are evaluated in name order, decrementing available stock as we go.
  Future<BulkProductionPlan> previewBulkProductionPlan({
    required List<BulkProductionSelection> selections,
  }) async {
    try {
      if (selections.isEmpty) {
        return BulkProductionPlan(products: [], materials: []);
      }

      final validSelections =
          selections.where((s) => s.batchCount > 0).toList(growable: false);
      if (validSelections.isEmpty) {
        return BulkProductionPlan(products: [], materials: []);
      }

      final productIds = validSelections.map((s) => s.productId).toList();
      final batchCountByProductId = <String, int>{
        for (final s in validSelections) s.productId: s.batchCount,
      };

      // 1) Fetch products in one query
      final productsResp = await _supabase
          .from('products')
          .select('id, name, units_per_batch, total_cost_per_batch, business_owner_id')
          .inFilter('id', productIds);

      final productsById = <String, Map<String, dynamic>>{};
      for (final row in (productsResp as List)) {
        productsById[row['id'] as String] = row as Map<String, dynamic>;
      }

      // 2) Fetch active recipes for these products
      final recipesResp = await _supabase
          .from('recipes')
          .select('id, product_id')
          .eq('is_active', true)
          .inFilter('product_id', productIds);

      final recipeIdByProductId = <String, String>{};
      for (final row in (recipesResp as List)) {
        final productId = row['product_id'] as String?;
        final recipeId = row['id'] as String?;
        if (productId != null && recipeId != null) {
          recipeIdByProductId[productId] = recipeId;
        }
      }

      final recipeIds = recipeIdByProductId.values.toSet().toList();

      // 3) Fetch recipe items for all recipes
      final recipeItemsResp = recipeIds.isEmpty
          ? <dynamic>[]
          : await _supabase
              .from('recipe_items')
              .select('id, recipe_id, stock_item_id, quantity_needed, usage_unit')
              .inFilter('recipe_id', recipeIds);

      final recipeItemsByProductId =
          <String, List<Map<String, dynamic>>>{}; // product_id -> items
      final allStockItemIds = <String>{};

      final recipeIdToProductId = <String, String>{
        for (final e in recipeIdByProductId.entries) e.value: e.key,
      };

      for (final row in (recipeItemsResp as List)) {
        final recipeId = row['recipe_id'] as String?;
        final productId = recipeId != null ? recipeIdToProductId[recipeId] : null;
        if (productId == null) continue;

        final item = row as Map<String, dynamic>;
        (recipeItemsByProductId[productId] ??= []).add(item);

        final sid = item['stock_item_id'] as String?;
        if (sid != null) allStockItemIds.add(sid);
      }

      // 4) Fetch only needed stock items
      final stockResp = allStockItemIds.isEmpty
          ? <dynamic>[]
          : await _supabase
              .from('stock_items')
              .select('id, name, unit, current_quantity, package_size, purchase_price')
              .inFilter('id', allStockItemIds.toList());

      final stockById = <String, Map<String, dynamic>>{};
      for (final row in (stockResp as List)) {
        stockById[row['id'] as String] = row as Map<String, dynamic>;
      }

      // 5) Compute required quantities (stock unit) per product and aggregated totals
      final requiredByProduct =
          <String, Map<String, double>>{}; // product_id -> (stock_item_id -> qty_in_stock_unit)
      final requiredAll = <String, double>{}; // stock_item_id -> total qty_in_stock_unit
      final perProductMaterials =
          <String, List<BulkProductMaterialLine>>{}; // product_id -> materials

      for (final productId in productIds) {
        final items = recipeItemsByProductId[productId] ?? const [];
        final batchCount = batchCountByProductId[productId] ?? 0;
        if (batchCount <= 0) continue;

        final perProduct = <String, double>{};
        final perProductLinesByKey = <String, BulkProductMaterialLine>{};
        for (final ri in items) {
          final stockItemId = ri['stock_item_id'] as String?;
          if (stockItemId == null) continue;

          final stock = stockById[stockItemId];
          if (stock == null) continue;

          final usageUnit = (ri['usage_unit'] as String?) ?? stock['unit'] as String;
          final stockUnit = stock['unit'] as String;
          final qtyPerBatch = (ri['quantity_needed'] as num).toDouble();
          final totalUsageQty = qtyPerBatch * batchCount;

          final convertedQty = UnitConversion.convert(
            quantity: totalUsageQty,
            fromUnit: usageUnit,
            toUnit: stockUnit,
          );

          perProduct[stockItemId] = (perProduct[stockItemId] ?? 0) + convertedQty;
          requiredAll[stockItemId] = (requiredAll[stockItemId] ?? 0) + convertedQty;

          final key = '$stockItemId|$usageUnit';
          final existing = perProductLinesByKey[key];
          if (existing == null) {
            perProductLinesByKey[key] = BulkProductMaterialLine(
              stockItemId: stockItemId,
              stockItemName: (stock['name'] as String?) ?? 'Unknown',
              quantityUsageUnit: totalUsageQty,
              usageUnit: usageUnit,
              quantityStockUnit: convertedQty,
              stockUnit: stockUnit,
            );
          } else {
            perProductLinesByKey[key] = BulkProductMaterialLine(
              stockItemId: stockItemId,
              stockItemName: existing.stockItemName,
              quantityUsageUnit: existing.quantityUsageUnit + totalUsageQty,
              usageUnit: existing.usageUnit,
              quantityStockUnit: existing.quantityStockUnit + convertedQty,
              stockUnit: existing.stockUnit,
            );
          }
        }
        requiredByProduct[productId] = perProduct;
        final lines = perProductLinesByKey.values.toList()
          ..sort((a, b) => a.stockItemName.toLowerCase().compareTo(b.stockItemName.toLowerCase()));
        perProductMaterials[productId] = lines;
      }

      // Build materials list (for FULL plan)
      final materials = <BulkMaterialSummary>[];
      for (final entry in requiredAll.entries) {
        final stock = stockById[entry.key];
        if (stock == null) continue;
        final current = (stock['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final required = entry.value;
        final shortage = (required - current) > 0 ? (required - current) : 0.0;
        final packageSize = ((stock['package_size'] as num?)?.toDouble() ?? 1.0);
        final normalizedPackage = packageSize > 0 ? packageSize : 1.0;
        final packagesNeeded = shortage <= 0 ? 0 : (shortage / normalizedPackage).ceil();

        materials.add(
          BulkMaterialSummary(
            stockItemId: entry.key,
            stockItemName: (stock['name'] as String?) ?? 'Unknown',
            stockUnit: (stock['unit'] as String?) ?? '',
            currentStock: current,
            requiredStockQty: required,
            shortageStockQty: shortage,
            packageSize: normalizedPackage,
            packagesNeeded: packagesNeeded,
          ),
        );
      }
      materials.sort((a, b) => a.stockItemName.toLowerCase().compareTo(b.stockItemName.toLowerCase()));

      // 6) Compute "produce now" partial plan (respect shared stock)
      final remainingStock = <String, double>{
        for (final s in stockById.entries)
          s.key: (s.value['current_quantity'] as num?)?.toDouble() ?? 0.0
      };

      final productPlans = <BulkProductionProductPlan>[];
      final sortedProducts = productIds.toList()
        ..sort((a, b) {
          final an = (productsById[a]?['name'] as String?) ?? '';
          final bn = (productsById[b]?['name'] as String?) ?? '';
          return an.toLowerCase().compareTo(bn.toLowerCase());
        });

      for (final productId in sortedProducts) {
        final p = productsById[productId];
        final productName = (p?['name'] as String?) ?? 'Unknown';
        final unitsPerBatch = (p?['units_per_batch'] as num?)?.toInt() ?? 1;
        final batchCount = batchCountByProductId[productId] ?? 0;
        final totalUnits = batchCount * unitsPerBatch;
        final totalCostPerBatch = (p?['total_cost_per_batch'] as num?)?.toDouble() ?? 0.0;
        final estimatedTotalCost = totalCostPerBatch * batchCount;

        final hasRecipe = recipeIdByProductId.containsKey(productId);
        if (!hasRecipe) {
          productPlans.add(
            BulkProductionProductPlan(
              productId: productId,
              productName: productName,
              batchCount: batchCount,
              unitsPerBatch: unitsPerBatch,
              totalUnits: totalUnits,
              estimatedTotalCost: estimatedTotalCost,
              hasActiveRecipe: false,
              canProduceNow: false,
              blockers: const [],
              materials: const [],
            ),
          );
          continue;
        }

        final req = requiredByProduct[productId] ?? const <String, double>{};
        final blockers = <BulkProductionBlocker>[];

        for (final r in req.entries) {
          final available = remainingStock[r.key] ?? 0.0;
          if (available + 1e-9 < r.value) {
            final stock = stockById[r.key];
            blockers.add(
              BulkProductionBlocker(
                stockItemId: r.key,
                stockItemName: (stock?['name'] as String?) ?? 'Unknown',
                stockUnit: (stock?['unit'] as String?) ?? '',
                shortageInStockUnit: r.value - available,
              ),
            );
          }
        }

        final canProduceNow = blockers.isEmpty;
        if (canProduceNow) {
          // decrement remaining stock for next products
          for (final r in req.entries) {
            remainingStock[r.key] = (remainingStock[r.key] ?? 0.0) - r.value;
          }
        }

        productPlans.add(
          BulkProductionProductPlan(
            productId: productId,
            productName: productName,
            batchCount: batchCount,
            unitsPerBatch: unitsPerBatch,
            totalUnits: totalUnits,
            estimatedTotalCost: estimatedTotalCost,
            hasActiveRecipe: true,
            canProduceNow: canProduceNow,
            blockers: blockers,
            materials: perProductMaterials[productId] ?? const [],
          ),
        );
      }

      return BulkProductionPlan(products: productPlans, materials: materials);
    } catch (e) {
      throw Exception('Failed to preview bulk production plan: $e');
    }
  }

  // ============================================================================
  // STOCK MOVEMENT TRACKING
  // ============================================================================

  /// Get stock movement history for a specific batch
  Future<List<Map<String, dynamic>>> getBatchMovementHistory(String batchId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('production_batch_stock_movements')
          .select('*')
          .eq('batch_id', batchId)
          .eq('business_owner_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Failed to fetch movement history: $e');
    }
  }

  /// Get stock movement history for all batches of a product
  Future<List<Map<String, dynamic>>> getProductMovementHistory(String productId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('production_batch_stock_movements')
          .select('''
            *,
            production_batches!inner(id, batch_date)
          ''')
          .eq('product_id', productId)
          .eq('business_owner_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => json as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Failed to fetch product movement history: $e');
    }
  }
}

