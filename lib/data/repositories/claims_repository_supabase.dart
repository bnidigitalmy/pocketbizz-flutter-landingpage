import 'package:flutter/foundation.dart' show debugPrint;
import '../../core/supabase/supabase_client.dart';
import '../models/claim.dart';

/// Claims Repository for Supabase
class ClaimsRepositorySupabase {
  /// Get all claims with pagination
  Future<Map<String, dynamic>> getAllClaims({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Get all deliveries grouped by vendor
      final deliveriesResponse = await supabase
          .from('vendor_deliveries')
          .select('''
            id,
            vendor_id,
            vendor_name,
            delivery_date,
            status,
            payment_status,
            total_amount
          ''')
          .order('delivery_date', ascending: false);

      final deliveries = deliveriesResponse as List<dynamic>;

      // Group by vendor and calculate totals
      final Map<String, Map<String, dynamic>> vendorClaims = {};

      for (var delivery in deliveries) {
        final vendorId = delivery['vendor_id'] as String;
        final vendorName = delivery['vendor_name'] as String;
        final totalAmount = (delivery['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paymentStatus = delivery['payment_status'] as String? ?? 'pending';

        if (!vendorClaims.containsKey(vendorId)) {
          vendorClaims[vendorId] = {
            'vendor_id': vendorId,
            'vendor_name': vendorName,
            'total_deliveries': 0,
            'total_amount': 0.0,
            'pending_amount': 0.0,
            'settled_amount': 0.0,
            'partial_amount': 0.0,
            'days_overdue': 0,
          };
        }

        final claim = vendorClaims[vendorId]!;
        claim['total_deliveries'] = (claim['total_deliveries'] as int) + 1;
        claim['total_amount'] = (claim['total_amount'] as double) + totalAmount;

        switch (paymentStatus) {
          case 'pending':
            claim['pending_amount'] = (claim['pending_amount'] as double) + totalAmount;
            break;
          case 'settled':
            claim['settled_amount'] = (claim['settled_amount'] as double) + totalAmount;
            break;
          case 'partial':
            claim['partial_amount'] = (claim['partial_amount'] as double) + totalAmount;
            break;
        }

        // Calculate days overdue (from oldest pending delivery)
        if (paymentStatus == 'pending' || paymentStatus == 'partial') {
          final deliveryDate = DateTime.parse(delivery['delivery_date'] as String);
          final daysDiff = DateTime.now().difference(deliveryDate).inDays;
          if (daysDiff > (claim['days_overdue'] as int)) {
            claim['days_overdue'] = daysDiff;
          }
        }
      }

      final claims = vendorClaims.values.map((v) => Claim.fromJson(v)).toList();

      // Apply pagination
      final paginatedClaims = claims.skip(offset).take(limit).toList();
      final hasMore = claims.length > offset + limit;

      return {
        'data': paginatedClaims,
        'hasMore': hasMore,
      };
    } catch (e) {
      throw Exception('Failed to fetch claims: $e');
    }
  }

  /// Get claim details for a specific vendor
  Future<ClaimDetails> getClaimDetails(String vendorId) async {
    try {
      // Get all deliveries for this vendor with items
      final deliveriesResponse = await supabase
          .from('vendor_deliveries')
          .select('''
            *,
            vendor_delivery_items (
              *,
              products (id, name, sku)
            )
          ''')
          .eq('vendor_id', vendorId)
          .order('delivery_date', ascending: false);

      final deliveries = deliveriesResponse as List<dynamic>;

      if (deliveries.isEmpty) {
        // Get vendor name
        final vendorResponse = await supabase
            .from('vendors')
            .select('name')
            .eq('id', vendorId)
            .single();

        return ClaimDetails(
          vendorId: vendorId,
          vendorName: vendorResponse['name'] as String,
          totalDeliveries: 0,
          totalAmount: 0.0,
          pendingAmount: 0.0,
          settledAmount: 0.0,
          partialAmount: 0.0,
          deliveries: [],
        );
      }

      // Get vendor name and commission rate
      final vendorName = deliveries.first['vendor_name'] as String;
      
      // Get vendor commission rate
      double commissionRate = 0.0;
      try {
        final vendorResponse = await supabase
            .from('vendors')
            .select('default_commission_rate')
            .eq('id', vendorId)
            .single();
        commissionRate = (vendorResponse['default_commission_rate'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('Error getting vendor commission: $e');
      }

      // Process deliveries with claim calculations
      final processedDeliveries = deliveries.map((delivery) {
        final deliveryJson = delivery as Map<String, dynamic>;
        final items = (deliveryJson['vendor_delivery_items'] as List<dynamic>?)
                ?.map((item) {
                  final itemJson = item as Map<String, dynamic>;
                  final product = itemJson['products'] as Map<String, dynamic>?;
                  
                  // Calculate claim amounts for each item
                  final quantity = (itemJson['quantity'] as num?)?.toDouble() ?? 0.0;
                  final unitPrice = (itemJson['unit_price'] as num?)?.toDouble() ?? 0.0;
                  final retailPrice = (itemJson['retail_price'] as num?)?.toDouble() ?? unitPrice;
                  final rejectedQty = (itemJson['rejected_qty'] as num?)?.toDouble() ?? 0.0;
                  
                  // Calculate gross (retail price * quantity)
                  final itemGross = retailPrice * quantity;
                  
                  // Calculate rejected amount
                  final itemRejected = retailPrice * rejectedQty;
                  
                  // Calculate net (gross - rejected)
                  final itemNet = itemGross - itemRejected;
                  
                  // Calculate commission (from vendor default commission rate)
                  final itemCommission = itemNet * (commissionRate / 100);
                  
                  // Calculate claimable (net - commission)
                  final itemClaimable = itemNet - itemCommission;

                  return {
                    ...itemJson,
                    'product_name': product?['name'] ?? itemJson['product_name'],
                    'item_gross': itemGross,
                    'item_rejected': itemRejected,
                    'item_net': itemNet,
                    'item_commission': itemCommission,
                    'item_claimable': itemClaimable,
                  };
                })
                .toList() ??
            [];

        // Calculate delivery totals
        final grossAmount = items.fold<double>(
          0.0,
          (sum, item) => sum + (item['item_gross'] as double),
        );
        final rejectedAmount = items.fold<double>(
          0.0,
          (sum, item) => sum + (item['item_rejected'] as double),
        );
        final commissionAmount = items.fold<double>(
          0.0,
          (sum, item) => sum + (item['item_commission'] as double),
        );
        final claimableAmount = items.fold<double>(
          0.0,
          (sum, item) => sum + (item['item_claimable'] as double),
        );

        return {
          ...deliveryJson,
          'items': items,
          'gross_amount': grossAmount,
          'rejected_amount': rejectedAmount,
          'commission_amount': commissionAmount,
          'claimable_amount': claimableAmount,
        };
      }).toList();

      // Calculate totals
      double totalAmount = 0.0;
      double pendingAmount = 0.0;
      double settledAmount = 0.0;
      double partialAmount = 0.0;

      for (var delivery in processedDeliveries) {
        final amount = (delivery['claimable_amount'] as num?)?.toDouble() ?? 
                      (delivery['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paymentStatus = delivery['payment_status'] as String? ?? 'pending';

        totalAmount += amount;

        switch (paymentStatus) {
          case 'pending':
            pendingAmount += amount;
            break;
          case 'settled':
            settledAmount += amount;
            break;
          case 'partial':
            partialAmount += amount;
            break;
        }
      }

      return ClaimDetails(
        vendorId: vendorId,
        vendorName: vendorName,
        totalDeliveries: deliveries.length,
        totalAmount: totalAmount,
        pendingAmount: pendingAmount,
        settledAmount: settledAmount,
        partialAmount: partialAmount,
        deliveries: processedDeliveries
            .map((d) => DeliveryWithClaimData.fromJson(d))
            .toList(),
      );
    } catch (e) {
      throw Exception('Failed to fetch claim details: $e');
    }
  }

  /// Update delivery item rejection
  Future<void> updateItemRejection({
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
}

