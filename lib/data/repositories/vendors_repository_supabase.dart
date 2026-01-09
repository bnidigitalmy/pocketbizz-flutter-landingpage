/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:flutter/foundation.dart' show debugPrint;
import '../../core/supabase/supabase_client.dart';
import '../models/vendor.dart';

class VendorsRepositorySupabase {
  // ============================================================================
  // VENDORS CRUD
  // ============================================================================

  /// Get all vendors
  Future<List<Vendor>> getAllVendors({
    bool activeOnly = false,
    int limit = 100,
    int offset = 0,
  }) async {
    dynamic query = supabase
        .from('vendors')
        .select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    query = query
        .order('name')
        .range(offset, offset + limit - 1); // Add pagination

    final response = await query;
    return (response as List)
        .map((json) => Vendor.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get vendor by ID
  Future<Vendor?> getVendorById(String vendorId) async {
    final response = await supabase
        .from('vendors')
        .select()
        .eq('id', vendorId)
        .maybeSingle();

    if (response == null) return null;
    return Vendor.fromJson(response as Map<String, dynamic>);
  }

  /// Create vendor
  Future<Vendor> createVendor({
    required String name,
    String? vendorNumber,
    String? email,
    String? phone,
    String? address,
    String commissionType = 'percentage',
    double defaultCommissionRate = 0.0,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('vendors')
        .insert({
      'business_owner_id': userId,
      'name': name,
      'vendor_number': vendorNumber,
      'email': email,
      'phone': phone,
      'address': address,
      'commission_type': commissionType,
      'default_commission_rate': defaultCommissionRate,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_holder': bankAccountHolder,
      'notes': notes,
    })
        .select()
        .single();

    return Vendor.fromJson(response as Map<String, dynamic>);
  }

  /// Update vendor
  Future<void> updateVendor(String vendorId, Map<String, dynamic> updates) async {
    final updateData = {
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    await supabase
        .from('vendors')
        .update(updateData)
        .eq('id', vendorId);
    
    // Verify update was successful by checking the updated row
    final verify = await supabase
        .from('vendors')
        .select()
        .eq('id', vendorId)
        .maybeSingle();
    
    if (verify == null) {
      throw Exception('Failed to update vendor: Vendor not found after update');
    }
  }

  /// Delete vendor
  Future<void> deleteVendor(String vendorId) async {
    await supabase
        .from('vendors')
        .delete()
        .eq('id', vendorId);
  }

  /// Toggle vendor active status
  Future<void> toggleVendorStatus(String vendorId, bool isActive) async {
    await updateVendor(vendorId, {'is_active': isActive});
  }

  // ============================================================================
  // VENDOR PRODUCTS
  // ============================================================================

  /// Assign product to vendor
  Future<void> assignProductToVendor({
    required String vendorId,
    required String productId,
    double? commissionRate,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    await supabase
        .from('vendor_products')
        .insert({
      'business_owner_id': userId,
      'vendor_id': vendorId,
      'product_id': productId,
      'commission_rate': commissionRate,
    });
  }

  /// Remove product from vendor
  Future<void> removeProductFromVendor(String vendorId, String productId) async {
    await supabase
        .from('vendor_products')
        .delete()
        .eq('vendor_id', vendorId)
        .eq('product_id', productId);
  }

  /// Get products assigned to vendor
  Future<List<Map<String, dynamic>>> getVendorProducts(String vendorId) async {
    final response = await supabase
        .from('vendor_products')
        .select('''
          *,
          products!inner(id, sku, name, sale_price, image_url)
        ''')
        .eq('vendor_id', vendorId)
        .eq('is_active', true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // ============================================================================
  // VENDOR SUMMARY (Using NEW Consignment System)
  // ============================================================================

  /// Get vendor summary (total sales, commission, payments) from NEW consignment tables
  Future<Map<String, dynamic>> getVendorSummary(String vendorId) async {
    // Get claims from NEW consignment_claims table
    final claims = await supabase
        .from('consignment_claims')
        .select('status, gross_amount, commission_amount, net_amount, paid_amount, balance_amount')
        .eq('vendor_id', vendorId);

    // Get deliveries stats
    final deliveries = await supabase
        .from('vendor_deliveries')
        .select('total_amount, status')
        .eq('vendor_id', vendorId);

    double totalDeliveryAmount = 0;
    int totalDeliveries = 0;
    int pendingDeliveries = 0;

    for (final delivery in deliveries as List) {
      final amount = (delivery['total_amount'] as num?)?.toDouble() ?? 0;
      final status = delivery['status'] as String?;
      
      totalDeliveryAmount += amount;
      totalDeliveries++;
      
      if (status == 'delivered') pendingDeliveries++;
    }

    double totalGrossAmount = 0;
    double totalCommission = 0;
    double totalNetAmount = 0;
    double totalPaidAmount = 0;
    double totalBalance = 0;
    int pendingClaims = 0;
    int approvedClaims = 0;
    int settledClaims = 0;

    for (final claim in claims as List) {
      final gross = (claim['gross_amount'] as num?)?.toDouble() ?? 0;
      final commission = (claim['commission_amount'] as num?)?.toDouble() ?? 0;
      final net = (claim['net_amount'] as num?)?.toDouble() ?? 0;
      final paid = (claim['paid_amount'] as num?)?.toDouble() ?? 0;
      final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0;
      final status = claim['status'] as String?;

      totalGrossAmount += gross;
      totalCommission += commission;
      totalNetAmount += net;
      totalPaidAmount += paid;
      totalBalance += balance;

      if (status == 'draft' || status == 'submitted') pendingClaims++;
      if (status == 'approved') approvedClaims++;
      if (status == 'settled') settledClaims++;
    }

    return {
      // Delivery stats
      'total_deliveries': totalDeliveries,
      'pending_deliveries': pendingDeliveries,
      'total_delivery_amount': totalDeliveryAmount,
      
      // Claims stats (from NEW consignment system)
      'total_gross_amount': totalGrossAmount,
      'total_commission': totalCommission,
      'total_net_amount': totalNetAmount,
      'total_paid_amount': totalPaidAmount,
      'outstanding_balance': totalBalance,
      
      // Claim counts
      'pending_claims': pendingClaims,
      'approved_claims': approvedClaims,
      'settled_claims': settledClaims,
    };
  }

  /// Get comprehensive vendor data for table view (all vendors with deliveries, claims, payments)
  Future<List<Map<String, dynamic>>> getAllVendorsComprehensiveData() async {
    final userId = supabase.auth.currentUser!.id;

    // Get all vendors
    final vendorsResponse = await supabase
        .from('vendors')
        .select('id, name, vendor_number, phone, email, is_active')
        .eq('business_owner_id', userId)
        .order('name');

    final vendors = vendorsResponse as List<dynamic>;
    final List<Map<String, dynamic>> comprehensiveData = [];

    for (var vendor in vendors) {
      final vendorId = vendor['id'] as String;
      final vendorName = vendor['name'] as String;
      final vendorNumber = vendor['vendor_number'] as String?;
      final phone = vendor['phone'] as String?;
      final email = vendor['email'] as String?;
      final isActive = vendor['is_active'] as bool? ?? true;

      // Get deliveries stats
      final deliveriesResponse = await supabase
          .from('vendor_deliveries')
          .select('id, delivery_date, status, payment_status, total_amount, invoice_number')
          .eq('vendor_id', vendorId)
          .order('delivery_date', ascending: false);

      final deliveries = deliveriesResponse as List<dynamic>;
      
      double totalDeliveryAmount = 0.0;
      int totalDeliveries = 0;
      int pendingDeliveries = 0;
      int deliveredCount = 0;
      String? lastDeliveryDate;

      for (var delivery in deliveries) {
        final amount = (delivery['total_amount'] as num?)?.toDouble() ?? 0.0;
        final status = delivery['status'] as String? ?? 'delivered';
        
        totalDeliveryAmount += amount;
        totalDeliveries++;
        
        if (status == 'delivered') deliveredCount++;
        if (status == 'pending') pendingDeliveries++;
        
        if (lastDeliveryDate == null) {
          lastDeliveryDate = delivery['delivery_date'] as String?;
        }
      }

      // Get claims stats from consignment_claims
      final claimsResponse = await supabase
          .from('consignment_claims')
          .select('claim_number, claim_date, status, gross_amount, commission_amount, net_amount, paid_amount, balance_amount')
          .eq('vendor_id', vendorId)
          .order('claim_date', ascending: false);

      final claims = claimsResponse as List<dynamic>;
      
      double totalGrossAmount = 0.0;
      double totalCommission = 0.0;
      double totalNetAmount = 0.0;
      double totalPaidAmount = 0.0;
      double totalBalance = 0.0;
      int pendingClaims = 0;
      int approvedClaims = 0;
      int settledClaims = 0;
      String? lastClaimDate;
      String? lastClaimNumber;

      for (var claim in claims) {
        final gross = (claim['gross_amount'] as num?)?.toDouble() ?? 0.0;
        final commission = (claim['commission_amount'] as num?)?.toDouble() ?? 0.0;
        final net = (claim['net_amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (claim['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;
        final status = claim['status'] as String? ?? 'draft';

        totalGrossAmount += gross;
        totalCommission += commission;
        totalNetAmount += net;
        totalPaidAmount += paid;
        totalBalance += balance;

        if (status == 'draft' || status == 'submitted') pendingClaims++;
        if (status == 'approved') approvedClaims++;
        if (status == 'settled') settledClaims++;

        if (lastClaimDate == null) {
          lastClaimDate = claim['claim_date'] as String?;
          lastClaimNumber = claim['claim_number'] as String?;
        }
      }

      // Get payments stats from consignment_payments
      final paymentsResponse = await supabase
          .from('consignment_payments')
          .select('payment_date, total_amount, payment_method, payment_reference')
          .eq('vendor_id', vendorId)
          .order('payment_date', ascending: false);

      final payments = paymentsResponse as List<dynamic>;
      
      double totalPaymentAmount = 0.0;
      int totalPayments = 0;
      String? lastPaymentDate;

      for (var payment in payments) {
        final amount = (payment['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalPaymentAmount += amount;
        totalPayments++;

        if (lastPaymentDate == null) {
          lastPaymentDate = payment['payment_date'] as String?;
        }
      }

      comprehensiveData.add({
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'vendor_number': vendorNumber,
        'phone': phone,
        'email': email,
        'is_active': isActive,
        
        // Deliveries
        'total_deliveries': totalDeliveries,
        'pending_deliveries': pendingDeliveries,
        'delivered_count': deliveredCount,
        'total_delivery_amount': totalDeliveryAmount,
        'last_delivery_date': lastDeliveryDate,
        
        // Claims
        'total_claims': pendingClaims + approvedClaims + settledClaims,
        'pending_claims': pendingClaims,
        'approved_claims': approvedClaims,
        'settled_claims': settledClaims,
        'total_gross_amount': totalGrossAmount,
        'total_commission': totalCommission,
        'total_net_amount': totalNetAmount,
        'total_paid_from_claims': totalPaidAmount,
        'total_balance': totalBalance,
        'last_claim_date': lastClaimDate,
        'last_claim_number': lastClaimNumber,
        
        // Payments
        'total_payments': totalPayments,
        'total_payment_amount': totalPaymentAmount,
        'last_payment_date': lastPaymentDate,
        
      // Calculated
      'outstanding_balance': totalBalance, // Same as total_balance from claims
    });
  }

  return comprehensiveData;
}

  /// Get detailed vendor data for table view (deliveries with items, claims, payments)
  Future<Map<String, dynamic>> getVendorDetailedData(String vendorId) async {
    final userId = supabase.auth.currentUser!.id;

    // Get vendor info
    final vendorResponse = await supabase
        .from('vendors')
        .select('id, name, vendor_number, phone, email, is_active')
        .eq('id', vendorId)
        .eq('business_owner_id', userId)
        .single();

    if (vendorResponse == null) {
      throw Exception('Vendor not found');
    }

    // Get all deliveries with items
    final deliveriesResponse = await supabase
        .from('vendor_deliveries')
        .select('''
          id,
          delivery_date,
          status,
          payment_status,
          total_amount,
          invoice_number,
          notes,
          vendor_delivery_items (
            id,
            product_id,
            product_name,
            quantity,
            unit_price,
            total_price,
            rejected_qty,
            quantity_sold,
            quantity_unsold,
            quantity_expired,
            quantity_damaged
          )
        ''')
        .eq('vendor_id', vendorId)
        .eq('business_owner_id', userId)
        .order('delivery_date', ascending: false);

    final deliveries = deliveriesResponse as List<dynamic>;
    
    // Process deliveries to ensure items are properly formatted
    final processedDeliveries = deliveries.map((delivery) {
      final deliveryMap = delivery as Map<String, dynamic>;
      final items = deliveryMap['vendor_delivery_items'];
      
      // Debug: Log items structure
      debugPrint('Processing delivery ${deliveryMap['invoice_number']}: items type = ${items.runtimeType}');
      
      // Ensure items is always a List
      List<dynamic> itemsList = [];
      if (items != null) {
        if (items is List) {
          itemsList = items;
          debugPrint('Items is List with ${itemsList.length} items');
        } else if (items is Map) {
          itemsList = [items];
          debugPrint('Items is Map, converted to List');
        } else {
          debugPrint('Items is unexpected type: ${items.runtimeType}');
        }
      } else {
        debugPrint('Items is null for delivery ${deliveryMap['invoice_number']}');
      }
      
      return {
        ...deliveryMap,
        'vendor_delivery_items': itemsList,
      };
    }).toList();

    // Get all claims
    final claimsResponse = await supabase
        .from('consignment_claims')
        .select('''
          id,
          claim_number,
          claim_date,
          status,
          gross_amount,
          commission_amount,
          net_amount,
          paid_amount,
          balance_amount,
          notes
        ''')
        .eq('vendor_id', vendorId)
        .eq('business_owner_id', userId)
        .order('claim_date', ascending: false);

    final claims = claimsResponse as List<dynamic>;

    // Get all payments
    final paymentsResponse = await supabase
        .from('consignment_payments')
        .select('''
          id,
          payment_date,
          total_amount,
          payment_method,
          payment_reference,
          notes
        ''')
        .eq('vendor_id', vendorId)
        .eq('business_owner_id', userId)
        .order('payment_date', ascending: false);

    final payments = paymentsResponse as List<dynamic>;

    return {
      'vendor': vendorResponse,
      'deliveries': processedDeliveries,
      'claims': claims,
      'payments': payments,
    };
  }
}
