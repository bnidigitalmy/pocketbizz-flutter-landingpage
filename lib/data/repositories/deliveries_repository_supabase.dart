import '../../core/supabase/supabase_client.dart';
import '../models/delivery.dart';

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
              })
              .toList() ??
          [];
      return Delivery.fromJson({
        ...deliveryJson,
        'items': items,
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
    final response = await supabase
        .from('vendor_deliveries')
        .select('''
          *,
          vendor_delivery_items (
            *,
            products (id, name, sku)
          )
        ''')
        .eq('id', deliveryId)
        .maybeSingle();

    if (response == null) return null;

    final deliveryJson = response as Map<String, dynamic>;
    final items = (deliveryJson['vendor_delivery_items'] as List<dynamic>?)
            ?.map((item) {
              final itemJson = item as Map<String, dynamic>;
              final product = itemJson['products'] as Map<String, dynamic>?;
              return {
                ...itemJson,
                'product_name': product?['name'] ?? itemJson['product_name'],
              };
            })
            .toList() ??
        [];

    return Delivery.fromJson({
      ...deliveryJson,
      'items': items,
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
          )
        ''')
        .eq('vendor_id', vendorId)
        .order('delivery_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    final deliveryJson = response as Map<String, dynamic>;
    final items = (deliveryJson['vendor_delivery_items'] as List<dynamic>?)
            ?.map((item) {
              final itemJson = item as Map<String, dynamic>;
              final product = itemJson['products'] as Map<String, dynamic>?;
              return {
                ...itemJson,
                'product_name': product?['name'] ?? itemJson['product_name'],
              };
            })
            .toList() ??
        [];

    return Delivery.fromJson({
      ...deliveryJson,
      'items': items,
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
    final userId = supabase.auth.currentUser!.id;

    // Get vendor name
    final vendorResponse = await supabase
        .from('vendors')
        .select('name')
        .eq('id', vendorId)
        .single();
    final vendorName = vendorResponse['name'] as String;

    // Calculate total amount based on ACCEPTED quantity only (quantity - rejected_qty)
    final totalAmount = items.fold<double>(
      0.0,
      (sum, item) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final rejectedQty = (item['rejected_qty'] as num?)?.toDouble() ?? 0.0;
        final acceptedQty = quantity - rejectedQty;
        final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        return sum + (acceptedQty * unitPrice);
      },
    );

    // Create delivery
    final deliveryResponse = await supabase
        .from('vendor_deliveries')
        .insert({
      'business_owner_id': userId,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'delivery_date': deliveryDate.toIso8601String().split('T')[0],
      'status': status,
      'total_amount': totalAmount,
      'notes': notes,
    })
        .select()
        .single();

    final deliveryId = deliveryResponse['id'] as String;

    // Create delivery items
    for (var item in items) {
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final rejectedQty = (item['rejected_qty'] as num?)?.toDouble() ?? 0.0;
      // Calculate total price based on ACCEPTED quantity only (quantity - rejectedQty)
      final acceptedQty = quantity - rejectedQty;
      final totalPrice = acceptedQty * unitPrice;

      await supabase.from('vendor_delivery_items').insert({
        'delivery_id': deliveryId,
        'product_id': item['product_id'] as String,
        'product_name': item['product_name'] as String,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice, // Based on accepted quantity
        'retail_price': (item['retail_price'] as num?)?.toDouble(),
        'rejected_qty': rejectedQty,
        'rejection_reason': item['rejection_reason'] as String?,
      });
    }

    final createdDelivery = await getDeliveryById(deliveryId);
    if (createdDelivery != null) {
      return createdDelivery;
    }

    // Fallback if getDeliveryById fails
    return Delivery(
      id: deliveryId,
      businessOwnerId: userId,
      vendorId: vendorId,
      vendorName: vendorName,
      deliveryDate: deliveryDate,
      status: status,
      totalAmount: totalAmount,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: items.map((item) => DeliveryItem(
        id: '',
        deliveryId: deliveryId,
        productId: item['product_id'] as String,
        productName: item['product_name'] as String,
        quantity: (item['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
        totalPrice: ((item['quantity'] as num?)?.toDouble() ?? 0.0) * ((item['unit_price'] as num?)?.toDouble() ?? 0.0),
        retailPrice: (item['retail_price'] as num?)?.toDouble(),
        rejectedQty: (item['rejected_qty'] as num?)?.toDouble() ?? 0.0,
        rejectionReason: item['rejection_reason'] as String?,
        createdAt: DateTime.now(),
      )).toList(),
    );
  }

  /// Update delivery status
  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    await supabase
        .from('vendor_deliveries')
        .update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', deliveryId);
  }

  /// Update delivery payment status
  Future<void> updateDeliveryPaymentStatus(String deliveryId, String paymentStatus) async {
    await supabase
        .from('vendor_deliveries')
        .update({
      'payment_status': paymentStatus,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', deliveryId);
  }

  /// Update delivery item rejection
  Future<void> updateDeliveryItemRejection({
    required String itemId,
    required double rejectedQty,
    required String? rejectionReason,
  }) async {
    await supabase
        .from('vendor_delivery_items')
        .update({
      'rejected_qty': rejectedQty,
      'rejection_reason': rejectionReason,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', itemId);
  }

  /// Get vendor commission info
  Future<Map<String, dynamic>?> getVendorCommission(String vendorId) async {
    try {
      final vendor = await supabase
          .from('vendors')
          .select('commission_type, default_commission_rate')
          .eq('id', vendorId)
          .single();

      final commissionType = vendor['commission_type'] as String? ?? 'percentage';
      final commissionRate = (vendor['default_commission_rate'] as num?)?.toDouble() ?? 0.0;

      return {
        'commissionType': commissionType,
        'percentage': commissionRate.toString(),
      };
    } catch (e) {
      return null;
    }
  }
}

