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
}
