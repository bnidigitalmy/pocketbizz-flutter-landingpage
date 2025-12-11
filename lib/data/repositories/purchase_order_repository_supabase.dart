import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchase_order.dart';
import '../models/stock_movement.dart';
import 'stock_repository_supabase.dart';
import '../../core/utils/unit_conversion.dart';

/// Purchase Order Repository using Supabase
class PurchaseOrderRepository {
  final SupabaseClient _supabase;

  PurchaseOrderRepository(this._supabase);

  /// Get all purchase orders for current user
  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Fetch POs with items
      final response = await _supabase
          .from('purchase_orders')
          .select('*, purchase_order_items(*)')
          .eq('business_owner_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        // Convert items array to PurchaseOrderItem list
        final itemsJson = json['purchase_order_items'] as List? ?? [];
        final items = itemsJson
            .map((item) => PurchaseOrderItem.fromJson(item as Map<String, dynamic>))
            .toList();

        // Create PO with items
        final poJson = Map<String, dynamic>.from(json);
        poJson['items'] = items.map((item) => item.toJson()).toList();
        return PurchaseOrder.fromJson(poJson);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch purchase orders: $e');
    }
  }

  /// Get single purchase order by ID
  Future<PurchaseOrder> getPurchaseOrderById(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('purchase_orders')
          .select('*, purchase_order_items(*)')
          .eq('id', id)
          .eq('business_owner_id', userId)
          .single();

      // Convert items
      final itemsJson = response['purchase_order_items'] as List? ?? [];
      final items = itemsJson
          .map((item) => PurchaseOrderItem.fromJson(item as Map<String, dynamic>))
          .toList();

      final poJson = Map<String, dynamic>.from(response);
      poJson['items'] = items.map((item) => item.toJson()).toList();
      return PurchaseOrder.fromJson(poJson);
    } catch (e) {
      throw Exception('Failed to fetch purchase order: $e');
    }
  }

  /// Update PO status
  Future<void> updateStatus(String id, String status) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final updateData = <String, dynamic>{'status': status};
      if (status == 'sent' && updateData['sent_at'] == null) {
        updateData['sent_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('purchase_orders')
          .update(updateData)
          .eq('id', id)
          .eq('business_owner_id', userId);
    } catch (e) {
      throw Exception('Failed to update PO status: $e');
    }
  }

  /// Mark PO as received (auto-update stock & create expense)
  Future<void> markAsReceived(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Call RPC function if exists, otherwise update manually
      try {
        await _supabase.rpc('receive_purchase_order', params: {'p_po_id': id});
      } catch (e) {
        // Fallback: manual update + stock increment
        // 1) Fetch PO with items
        final poWithItems = await _supabase
            .from('purchase_orders')
            .select('*, purchase_order_items(*)')
            .eq('id', id)
            .eq('business_owner_id', userId)
            .single();

        final itemsJson = poWithItems['purchase_order_items'] as List? ?? [];
        final stockRepo = StockRepository(_supabase);

        for (final item in itemsJson) {
          final stockItemId = item['stock_item_id'] as String?;
          final poItemQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final poItemUnit = (item['unit'] as String?) ?? 'pcs';
          
          if (stockItemId == null || poItemQty == 0) continue;

          try {
            // Get stock item to know its unit
            final stockItem = await stockRepo.getStockItemById(stockItemId);
            if (stockItem == null) {
              debugPrint('Stock item not found: $stockItemId');
              continue;
            }

            // Convert quantity from PO item unit to stock item unit
            final convertedQty = UnitConversion.convert(
              quantity: poItemQty,
              fromUnit: poItemUnit,
              toUnit: stockItem.unit,
            );

            await stockRepo.recordStockMovement(
              StockMovementInput(
                stockItemId: stockItemId,
                movementType: StockMovementType.purchase,
                quantityChange: convertedQty,
                reason: 'Purchase Order: $id',
                referenceId: id,
                referenceType: 'purchase_order',
              ),
            );
          } catch (movementError) {
            // If one item fails, continue with others but log
            debugPrint('Failed to update stock for PO item $stockItemId: $movementError');
          }
        }

        // 2) Create expense record
        try {
          final poData = poWithItems as Map<String, dynamic>;
          final totalAmount = (poData['total_amount'] as num?)?.toDouble() ?? 0.0;
          final supplierId = poData['supplier_id'] as String?;
          final poNumber = poData['po_number'] as String? ?? '';

          final expenseResponse = await _supabase
              .from('expenses')
              .insert({
                'business_owner_id': userId,
                'vendor_id': supplierId,
                'amount': totalAmount,
                'category': 'Bahan Mentah (PO)',  // Specific category for PO purchases to distinguish from manual entries
                'currency': 'MYR',
                'expense_date': DateTime.now().toIso8601String().split('T')[0], // Date only
                'notes': 'Purchase Order: $poNumber',
              })
              .select()
              .single();

          final expenseId = expenseResponse['id'] as String?;

          // 3) Update PO status to received and link expense
          await _supabase
              .from('purchase_orders')
              .update({
                'status': 'received',
                'received_at': DateTime.now().toIso8601String(),
                'expense_id': expenseId,
              })
              .eq('id', id)
              .eq('business_owner_id', userId);
        } catch (expenseError) {
          debugPrint('Failed to create expense for PO: $expenseError');
          // Still update PO status even if expense creation fails
          await _supabase
              .from('purchase_orders')
              .update({
                'status': 'received',
                'received_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id)
              .eq('business_owner_id', userId);
        }
      }
    } catch (e) {
      throw Exception('Failed to mark PO as received: $e');
    }
  }

  /// Delete purchase order
  Future<void> deletePurchaseOrder(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase
          .from('purchase_orders')
          .delete()
          .eq('id', id)
          .eq('business_owner_id', userId);
    } catch (e) {
      throw Exception('Failed to delete purchase order: $e');
    }
  }

  /// Update purchase order
  Future<void> updatePurchaseOrder(String id, Map<String, dynamic> data) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Update PO
      final poData = Map<String, dynamic>.from(data);
      poData.remove('items'); // Items handled separately

      await _supabase
          .from('purchase_orders')
          .update(poData)
          .eq('id', id)
          .eq('business_owner_id', userId);

      // Update items if provided
      if (data['items'] != null) {
        final items = data['items'] as List;
        
        // Delete existing items
        await _supabase
            .from('purchase_order_items')
            .delete()
            .eq('po_id', id);

        // Insert new items
        if (items.isNotEmpty) {
          final itemsToInsert = items.map((item) {
            final itemMap = Map<String, dynamic>.from(item);
            itemMap['po_id'] = id;
            itemMap['business_owner_id'] = userId;
            return itemMap;
          }).toList();

          await _supabase
              .from('purchase_order_items')
              .insert(itemsToInsert);
        }
      }
    } catch (e) {
      throw Exception('Failed to update purchase order: $e');
    }
  }

  /// Duplicate purchase order
  Future<PurchaseOrder> duplicatePurchaseOrder(String id) async {
    try {
      final original = await getPurchaseOrderById(id);
      
      // Generate new PO number
      final newPONumber = 'PO-${DateTime.now().millisecondsSinceEpoch}';
      
      // Create new PO
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final newPOData = {
        'business_owner_id': userId,
        'po_number': newPONumber,
        'supplier_id': original.supplierId,
        'supplier_name': original.supplierName,
        'supplier_phone': original.supplierPhone,
        'supplier_email': original.supplierEmail,
        'supplier_address': original.supplierAddress,
        'delivery_address': original.deliveryAddress,
        'total_amount': original.totalAmount,
        'status': 'draft',
        'notes': original.notes,
        'expected_delivery_date': original.expectedDeliveryDate,
        'payment_terms': original.paymentTerms,
        'payment_method': original.paymentMethod,
        'requested_by': original.requestedBy,
        'discount': original.discount,
        'tax': original.tax,
        'shipping_charges': original.shippingCharges,
      };

      final newPOResponse = await _supabase
          .from('purchase_orders')
          .insert(newPOData)
          .select()
          .single();

      // Duplicate items
      if (original.items.isNotEmpty) {
        final itemsToInsert = original.items.map((item) {
          return {
            'po_id': newPOResponse['id'],
            'business_owner_id': userId,
            'stock_item_id': item.stockItemId,
            'item_name': item.itemName,
            'quantity': item.quantity,
            'unit': item.unit,
            'estimated_price': item.estimatedPrice,
            'notes': item.notes,
          };
        }).toList();

        await _supabase
            .from('purchase_order_items')
            .insert(itemsToInsert);
      }

      return await getPurchaseOrderById(newPOResponse['id']);
    } catch (e) {
      throw Exception('Failed to duplicate purchase order: $e');
    }
  }

  /// Create PO from shopping cart
  Future<PurchaseOrder> createPOFromCart({
    required String? supplierId,
    required String supplierName,
    String? supplierPhone,
    String? supplierEmail,
    String? supplierAddress,
    String? deliveryAddress,
    String? notes,
    required List<String> cartItemIds,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Generate PO number
      final poNumber = 'PO-${DateTime.now().millisecondsSinceEpoch}';

      // Get cart items
      dynamic cartQuery = _supabase
          .from('shopping_cart_items')
          .select('*, stock_items(*)')
          .eq('business_owner_id', userId);
      
      // Filter by IDs
      if (cartItemIds.isNotEmpty) {
        cartQuery = cartQuery.inFilter('id', cartItemIds);
      }
      
      final cartResponse = await cartQuery;

      final cartItems = cartResponse as List;
      if (cartItems.isEmpty) {
        throw Exception('Cart items not found');
      }

      // Create vendor if supplier is new (supplierId is null)
      String? finalSupplierId = supplierId;
      if (supplierId == null && supplierName.trim().isNotEmpty) {
        try {
          // Check if vendor with same name already exists
          final existingVendor = await _supabase
              .from('vendors')
              .select('id')
              .eq('business_owner_id', userId)
              .eq('name', supplierName.trim())
              .maybeSingle();
          
          if (existingVendor != null) {
            // Use existing vendor
            finalSupplierId = existingVendor['id'] as String;
          } else {
            // Create new vendor with type 'supplier'
            final vendorResponse = await _supabase
                .from('vendors')
                .insert({
                  'business_owner_id': userId,
                  'name': supplierName.trim(),
                  'email': supplierEmail?.trim(),
                  'phone': supplierPhone?.trim(),
                  'address': supplierAddress?.trim(),
                  'type': 'supplier',  // Mark as supplier
                  'is_active': true,
                })
                .select()
                .single();
            
            finalSupplierId = vendorResponse['id'] as String;
            debugPrint('Created new supplier vendor: $finalSupplierId');
          }
        } catch (e) {
          debugPrint('Failed to create vendor, continuing with PO creation: $e');
          // Continue without vendor ID - PO will still have supplier_name
        }
      }

      // Calculate total
      double totalAmount = 0.0;
      final poItems = <Map<String, dynamic>>[];

      for (final cartItem in cartItems) {
        final stockItem = cartItem['stock_items'] as Map<String, dynamic>?;
        final qty = (cartItem['shortage_qty'] as num).toDouble();
        final purchasePrice = stockItem != null
            ? (stockItem['purchase_price'] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final packageSize = stockItem != null
            ? (stockItem['package_size'] as num?)?.toDouble() ?? 1.0
            : 1.0;

        // Get item name from stock_items join (stock_item_name doesn't exist in cart table)
        final itemName = stockItem?['name'] as String? ??
            'Unknown Item';

        // Calculate cost (packages needed * price per package)
        final packagesNeeded = (qty / packageSize).ceil();
        final itemCost = packagesNeeded * purchasePrice;
        totalAmount += itemCost;

        poItems.add({
          'stock_item_id': cartItem['stock_item_id'],
          'item_name': itemName,
          'quantity': qty,
          'unit': cartItem['unit'] ?? stockItem?['unit'] ?? 'pcs',
          'estimated_price': purchasePrice,
          'notes': cartItem['notes'],
        });
      }

      // Create PO
      final poData = {
        'business_owner_id': userId,
        'po_number': poNumber,
        'supplier_id': finalSupplierId,  // Use created vendor ID if new supplier
        'supplier_name': supplierName,
        'supplier_phone': supplierPhone,
        'supplier_email': supplierEmail,
        'supplier_address': supplierAddress,
        'delivery_address': deliveryAddress,
        'total_amount': totalAmount,
        'status': 'draft',
        'notes': notes,
      };

      final poResponse = await _supabase
          .from('purchase_orders')
          .insert(poData)
          .select()
          .single();

      // Create PO items
      if (poItems.isNotEmpty) {
        final itemsToInsert = poItems.map((item) {
          return {
            ...item,
            'po_id': poResponse['id'],
            'business_owner_id': userId,
          };
        }).toList();

        await _supabase
            .from('purchase_order_items')
            .insert(itemsToInsert);
      }

      // Clear cart items - delete one by one if needed
      for (final itemId in cartItemIds) {
        await _supabase
            .from('shopping_cart_items')
            .delete()
            .eq('id', itemId)
            .eq('business_owner_id', userId);
      }

      return await getPurchaseOrderById(poResponse['id']);
    } catch (e) {
      throw Exception('Failed to create PO from cart: $e');
    }
  }
}

