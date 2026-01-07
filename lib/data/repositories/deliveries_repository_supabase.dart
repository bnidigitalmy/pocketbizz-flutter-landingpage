/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'dart:convert';
import '../../core/supabase/supabase_client.dart';
import '../models/delivery.dart';
import '../models/delivery_timeline.dart';
import '../models/delivery_note.dart';
import 'production_repository_supabase.dart';

/// Deliveries Repository for Supabase
class DeliveriesRepositorySupabase {
  /// Get all deliveries with pagination
  Future<Map<String, dynamic>> getAllDeliveries({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await supabase
        .from('vendor_deliveries')
        .select('''
          *,
          vendors!inner(vendor_number),
          vendor_delivery_items (
            *,
            products (id, name, sku)
          )
        ''')
        .order('delivery_date', ascending: false)
        .range(offset, offset + limit - 1);

    final deliveries = (response as List).map((json) {
      final deliveryJson = json as Map<String, dynamic>;
      final items = (deliveryJson['vendor_delivery_items'] as List<dynamic>?)
              ?.map((item) {
            final itemJson = item as Map<String, dynamic>;
            final product = itemJson['products'] as Map<String, dynamic>?;
            return {
              ...itemJson,
              'product_name': product?['name'] ?? itemJson['product_name'],
            };
          }).toList() ??
          [];
      
      // Extract vendor_number from vendors relation
      final vendorData = deliveryJson['vendors'] as Map<String, dynamic>?;
      final vendorNumber = vendorData?['vendor_number'] as String?;
      
      return Delivery.fromJson({
        ...deliveryJson,
        'items': items,
        'vendor_number': vendorNumber,
      });
    }).toList();

    // Check if there are more pages
    final hasMore = deliveries.length == limit;

    return {
      'data': deliveries,
      'hasMore': hasMore,
    };
  }

  /// Get delivery by ID
  Future<Delivery?> getDeliveryById(String deliveryId) async {
    final response = await supabase.from('vendor_deliveries').select('''
          *,
          vendor_delivery_items (
            *,
            products (id, name, sku)
          ),
          vendors!inner (vendor_number)
        ''').eq('id', deliveryId).maybeSingle();

    if (response == null) return null;

    final deliveryJson = response as Map<String, dynamic>;
    final items =
        (deliveryJson['vendor_delivery_items'] as List<dynamic>?)?.map((item) {
              final itemJson = item as Map<String, dynamic>;
              final product = itemJson['products'] as Map<String, dynamic>?;
              return {
                ...itemJson,
                'product_name': product?['name'] ?? itemJson['product_name'],
              };
            }).toList() ??
            [];
    
    // Extract vendor_number from vendors relation
    final vendorData = deliveryJson['vendors'] as Map<String, dynamic>?;
    final vendorNumber = vendorData?['vendor_number'] as String?;

    return Delivery.fromJson({
      ...deliveryJson,
      'items': items,
      'vendor_number': vendorNumber,
    });
  }

  /// Get last delivery for a vendor
  Future<Delivery?> getLastDeliveryForVendor(String vendorId) async {
    final response = await supabase
        .from('vendor_deliveries')
        .select('''
          *,
          vendor_delivery_items (
            *,
            products (id, name, sku)
          ),
          vendors!inner (vendor_number)
        ''')
        .eq('vendor_id', vendorId)
        .order('delivery_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    final deliveryJson = response as Map<String, dynamic>;
    final items =
        (deliveryJson['vendor_delivery_items'] as List<dynamic>?)?.map((item) {
              final itemJson = item as Map<String, dynamic>;
              final product = itemJson['products'] as Map<String, dynamic>?;
              return {
                ...itemJson,
                'product_name': product?['name'] ?? itemJson['product_name'],
              };
            }).toList() ??
            [];
    
    // Extract vendor_number from vendors relation
    final vendorData = deliveryJson['vendors'] as Map<String, dynamic>?;
    final vendorNumber = vendorData?['vendor_number'] as String?;

    return Delivery.fromJson({
      ...deliveryJson,
      'items': items,
      'vendor_number': vendorNumber,
    });
  }

  /// Create delivery
  Future<Delivery> createDelivery({
    required String vendorId,
    required DateTime deliveryDate,
    required String status,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    // Atomic DB transaction: create vendor delivery + items + deduct FIFO in one RPC
    final deliveryId = await supabase.rpc(
      'create_vendor_delivery_and_deduct_fifo',
      params: {
        'p_vendor_id': vendorId,
        'p_delivery_date': deliveryDate.toIso8601String().split('T')[0],
        'p_status': status,
        'p_notes': notes,
        'p_items': items,
      },
    ) as String;

    final createdDelivery = await getDeliveryById(deliveryId);
    if (createdDelivery != null) {
      return createdDelivery;
    }

    // Fallback if getDeliveryById fails
    return Delivery(
      id: deliveryId,
      businessOwnerId: supabase.auth.currentUser!.id,
      vendorId: vendorId,
      vendorName: '',
      deliveryDate: deliveryDate,
      status: status,
      totalAmount: 0,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: items
          .map((item) => DeliveryItem(
                id: '',
                deliveryId: deliveryId,
                productId: item['product_id'] as String,
                productName: item['product_name'] as String,
                quantity: (item['quantity'] as num?)?.toDouble() ?? 0.0,
                unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
                totalPrice: ((item['quantity'] as num?)?.toDouble() ?? 0.0) *
                    ((item['unit_price'] as num?)?.toDouble() ?? 0.0),
                retailPrice: (item['retail_price'] as num?)?.toDouble(),
                rejectedQty: (item['rejected_qty'] as num?)?.toDouble() ?? 0.0,
                rejectionReason: item['rejection_reason'] as String?,
                createdAt: DateTime.now(),
              ))
          .toList(),
    );
  }

  /// Update delivery status
  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    await supabase.from('vendor_deliveries').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', deliveryId);
  }

  /// Update delivery payment status
  Future<void> updateDeliveryPaymentStatus(
      String deliveryId, String paymentStatus) async {
    await supabase.from('vendor_deliveries').update({
      'payment_status': paymentStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', deliveryId);
  }

  /// Update delivery item rejection
  Future<void> updateDeliveryItemRejection({
    required String itemId,
    required double rejectedQty,
    required String? rejectionReason,
  }) async {
    await supabase.from('vendor_delivery_items').update({
      'rejected_qty': rejectedQty,
      'rejection_reason': rejectionReason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);
  }

  /// Update delivery item quantities (sold, unsold, expired, damaged)
  /// Used in claims flow to update quantities before creating claim
  Future<void> updateDeliveryItemQuantities({
    required String itemId,
    required double quantitySold,
    required double quantityUnsold,
    required double quantityExpired,
    required double quantityDamaged,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get current item to validate
    final itemResponse = await supabase
        .from('vendor_delivery_items')
        .select('quantity, delivery_id')
        .eq('id', itemId)
        .single();

    final item = itemResponse as Map<String, dynamic>;
    final totalQuantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    final total =
        quantitySold + quantityUnsold + quantityExpired + quantityDamaged;

    // Validate quantities balance
    if ((total - totalQuantity).abs() > 0.01) {
      throw Exception('Jumlah kuantiti tidak sepadan. '
          'Dihantar: ${totalQuantity.toStringAsFixed(2)}, '
          'Jumlah: ${total.toStringAsFixed(2)}. '
          'Sila pastikan jumlah sama dengan kuantiti dihantar.');
    }

    // Update quantities
    await supabase.from('vendor_delivery_items').update({
      'quantity_sold': quantitySold,
      'quantity_unsold': quantityUnsold,
      'quantity_expired': quantityExpired,
      'quantity_damaged': quantityDamaged,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);
  }

  /// Batch update multiple delivery items quantities
  Future<void> batchUpdateDeliveryItemQuantities({
    required List<Map<String, dynamic>> updates,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Validate all updates first
    for (var update in updates) {
      final itemId = update['itemId'] as String;
      final quantitySold = (update['quantitySold'] as num?)?.toDouble() ?? 0.0;
      final quantityUnsold =
          (update['quantityUnsold'] as num?)?.toDouble() ?? 0.0;
      final quantityExpired =
          (update['quantityExpired'] as num?)?.toDouble() ?? 0.0;
      final quantityDamaged =
          (update['quantityDamaged'] as num?)?.toDouble() ?? 0.0;

      // Get item to validate
      final itemResponse = await supabase
          .from('vendor_delivery_items')
          .select('quantity')
          .eq('id', itemId)
          .single();

      final item = itemResponse as Map<String, dynamic>;
      final totalQuantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final total =
          quantitySold + quantityUnsold + quantityExpired + quantityDamaged;

      if ((total - totalQuantity).abs() > 0.01) {
        throw Exception(
            'Item ${update['productName'] ?? itemId}: Jumlah kuantiti tidak sepadan. '
            'Dihantar: ${totalQuantity.toStringAsFixed(2)}, Jumlah: ${total.toStringAsFixed(2)}');
      }
    }

    // Update all items
    for (var update in updates) {
      await supabase.from('vendor_delivery_items').update({
        'quantity_sold': update['quantitySold'],
        'quantity_unsold': update['quantityUnsold'],
        'quantity_expired': update['quantityExpired'],
        'quantity_damaged': update['quantityDamaged'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', update['itemId']);
    }
  }

  /// Get vendor commission info
  Future<Map<String, dynamic>?> getVendorCommission(String vendorId) async {
    try {
      final vendor = await supabase
          .from('vendors')
          .select('commission_type, default_commission_rate')
          .eq('id', vendorId)
          .single();

      final commissionType =
          vendor['commission_type'] as String? ?? 'percentage';
      final commissionRate =
          (vendor['default_commission_rate'] as num?)?.toDouble() ?? 0.0;

      return {
        'commissionType': commissionType,
        'percentage': commissionRate.toString(),
      };
    } catch (e) {
      return null;
    }
  }

  /// Get delivery timeline events
  Future<List<DeliveryTimelineEvent>> getDeliveryTimeline(String deliveryId) async {
    final response = await supabase
        .from('delivery_timeline')
        .select('*')
        .eq('delivery_id', deliveryId)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      return DeliveryTimelineEvent.fromJson(json as Map<String, dynamic>);
    }).toList();
  }

  /// Get delivery notes
  Future<List<DeliveryNote>> getDeliveryNotes(String deliveryId) async {
    final response = await supabase
        .from('delivery_notes_log')
        .select('*')
        .eq('delivery_id', deliveryId)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      return DeliveryNote.fromJson(json as Map<String, dynamic>);
    }).toList();
  }

  /// Add note to delivery
  Future<DeliveryNote> addDeliveryNote({
    required String deliveryId,
    required String note,
    String noteType = 'general',
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get user name
    String? userName;
    try {
      final userResponse = await supabase
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      if (userResponse != null) {
        userName = userResponse['full_name'] as String?;
      }
    } catch (e) {
      // Ignore error, use null
    }

    // Get delivery to get business_owner_id
    final deliveryResponse = await supabase
        .from('vendor_deliveries')
        .select('business_owner_id')
        .eq('id', deliveryId)
        .single();

    final businessOwnerId = deliveryResponse['business_owner_id'] as String;

    final response = await supabase
        .from('delivery_notes_log')
        .insert({
          'delivery_id': deliveryId,
          'business_owner_id': businessOwnerId,
          'note': note,
          'note_type': noteType,
          'added_by_user_id': userId,
          'added_by_name': userName,
        })
        .select()
        .single();

    // Also log in timeline
    await supabase.from('delivery_timeline').insert({
      'delivery_id': deliveryId,
      'business_owner_id': businessOwnerId,
      'event_type': 'note_added',
      'description': 'Nota ditambah',
      'changed_by_user_id': userId,
      'changed_by_name': userName ?? 'System',
      'metadata': jsonEncode({'note_type': noteType}),
    });

    return DeliveryNote.fromJson(response as Map<String, dynamic>);
  }

  /// Get delivery summary for vendor
  Future<Map<String, dynamic>> getVendorDeliverySummary(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get total deliveries count
    final deliveriesCountResponse = await supabase
        .from('vendor_deliveries')
        .select('id')
        .eq('business_owner_id', userId)
        .eq('vendor_id', vendorId)
        .count();
    final totalDeliveries = deliveriesCountResponse.count ?? 0;

    // Get pending deliveries
    final pendingCountResponse = await supabase
        .from('vendor_deliveries')
        .select('id')
        .eq('business_owner_id', userId)
        .eq('vendor_id', vendorId)
        .eq('status', 'pending')
        .count();
    final pendingDeliveries = pendingCountResponse.count ?? 0;

    // Get delivered count
    final deliveredCountResponse = await supabase
        .from('vendor_deliveries')
        .select('id')
        .eq('business_owner_id', userId)
        .eq('vendor_id', vendorId)
        .eq('status', 'delivered')
        .count();
    final deliveredCount = deliveredCountResponse.count ?? 0;

    // Get total amount
    final totalAmountResponse = await supabase
        .from('vendor_deliveries')
        .select('total_amount')
        .eq('business_owner_id', userId)
        .eq('vendor_id', vendorId);

    double totalAmount = 0.0;
    if (totalAmountResponse is List) {
      for (var delivery in totalAmountResponse) {
        final amount = (delivery['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalAmount += amount;
      }
    }

    // Get last delivery date
    final lastDeliveryResponse = await supabase
        .from('vendor_deliveries')
        .select('delivery_date')
        .eq('business_owner_id', userId)
        .eq('vendor_id', vendorId)
        .order('delivery_date', ascending: false)
        .limit(1)
        .maybeSingle();

    return {
      'total_deliveries': totalDeliveries,
      'pending_deliveries': pendingDeliveries,
      'delivered_count': deliveredCount,
      'total_amount': totalAmount,
      'last_delivery_date': lastDeliveryResponse?['delivery_date'],
    };
  }
}
