/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:postgrest/postgrest.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/consignment_claim.dart';
import '../models/delivery.dart';
import '../models/claim_validation_result.dart';
import '../models/claim_summary.dart';
import 'vendor_commission_price_ranges_repository_supabase.dart';

/// Consignment Claims Repository for Supabase
/// Works with new consignment_claims and consignment_claim_items tables
class ConsignmentClaimsRepositorySupabase {
  Future<int> _getNextClaimSeqForMonth({
    required String userId,
    required String prefixWithDash, // e.g. "CLM-2512-" or "ABC-2512-"
  }) async {
    // Query a small window of recent claim_numbers for this month and pick max suffix.
    final rows = await supabase
        .from('consignment_claims')
        .select('claim_number')
        .eq('business_owner_id', userId)
        .like('claim_number', '$prefixWithDash%')
        .order('claim_number', ascending: false)
        .limit(50);

    int maxSeq = 0;
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final claimNumber = row['claim_number'] as String?;
      if (claimNumber == null) continue;
      final lastDash = claimNumber.lastIndexOf('-');
      if (lastDash < 0 || lastDash == claimNumber.length - 1) continue;
      final suffix = claimNumber.substring(lastDash + 1);
      final n = int.tryParse(suffix);
      if (n != null && n > maxSeq) maxSeq = n;
    }

    return maxSeq + 1;
  }

  /// Get claim prefix from business_profile (optional user prefix)
  /// Returns format: "USER_PREFIX-CLM" or "CLM" if no user prefix
  Future<String> _getClaimPrefix(String userId) async {
    try {
      final profileResponse = await supabase
          .from('business_profile')
          .select('claim_prefix')
          .eq('business_owner_id', userId)
          .maybeSingle();
      
      final userPrefix = profileResponse?['claim_prefix'] as String?;
      if (userPrefix != null && userPrefix.isNotEmpty) {
        return '${userPrefix.toUpperCase()}-CLM';
      }
      return 'CLM'; // No user prefix, use original format
    } catch (e) {
      debugPrint('Error fetching claim prefix from business_profile: $e');
      return 'CLM'; // Fallback to default
    }
  }

  /// Create claim from deliveries
  /// Optional: itemMetadata to specify carry_forward_status per delivery item
  /// Format: {'<delivery_item_id>': {'carry_forward_status': 'carry_forward'|'loss'|'none'}}
  /// Optional: carryForwardItems to include C/F items (not part of current deliveries)
  /// Each item should include: delivery_id, delivery_item_id, product_name, quantity, unit_price,
  /// quantity_sold, quantity_unsold, quantity_expired, quantity_damaged
  Future<ConsignmentClaim> createClaim({
    required String vendorId,
    required List<String> deliveryIds,
    required DateTime claimDate,
    String? notes,
    Map<String, Map<String, dynamic>>? itemMetadata,
    List<Map<String, dynamic>>? carryForwardItems,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    String _buildInFilter(List<String> values) =>
        '(${values.map((v) => '"$v"').join(',')})';

    List deliveries = [];
    if (deliveryIds.isNotEmpty) {
    // Get deliveries to validate
    final deliveriesResponse = await supabase
        .from('vendor_deliveries')
        .select('id, vendor_id, vendor_name')
        .filter('id', 'in', _buildInFilter(deliveryIds))
        .eq('business_owner_id', userId);

      deliveries = deliveriesResponse as List;
    if (deliveries.length != deliveryIds.length) {
      throw Exception('Some deliveries not found');
    }

    // Verify all deliveries are for the same vendor
      final vendorIds =
          deliveries.map((d) => (d as Map)['vendor_id'] as String).toSet();
    if (vendorIds.length > 1 || !vendorIds.contains(vendorId)) {
      throw Exception('All deliveries must be for the same vendor');
      }
    }

    // Check if any delivery has already been claimed (draft, submitted, approved, settled, or rejected)
    // We include ALL statuses except only archived/deleted to prevent duplicate claims
    final existingClaimsResponse = await supabase
        .from('consignment_claim_items')
        .select('''
          delivery_id,
          claim:consignment_claims!inner (
            id,
            claim_number,
            status
          )
        ''')
        .filter('delivery_id', 'in', _buildInFilter(deliveryIds))
        .inFilter('claim.status',
            ['draft', 'submitted', 'approved', 'settled', 'rejected']);

    final existingClaims = existingClaimsResponse as List;
    if (existingClaims.isNotEmpty) {
      final claimedDeliveryIds = <String>{};
      final claimNumbers = <String>{};

      for (var item in existingClaims) {
        final itemMap = item as Map<String, dynamic>;
        final deliveryId = itemMap['delivery_id'] as String;
        final claim = itemMap['claim'] as Map<String, dynamic>;
        final claimNumber = claim['claim_number'] as String;

        claimedDeliveryIds.add(deliveryId);
        claimNumbers.add(claimNumber);
      }

      final deliveryNumbers = <String>[];
      for (var deliveryId in claimedDeliveryIds) {
        final delivery = deliveries.firstWhere(
          (d) => (d as Map)['id'] == deliveryId,
          orElse: () => null,
        );
        if (delivery != null) {
          final invoiceNumber =
              (delivery as Map)['invoice_number'] as String? ??
                  deliveryId.substring(0, 8);
          deliveryNumbers.add(invoiceNumber);
        }
      }

      throw Exception(
          '⚠️ AMARAN: Invoice penghantaran berikut telah dibuat tuntutan:\n'
          '${deliveryNumbers.join(', ')}\n\n'
          'Tuntutan yang berkaitan: ${claimNumbers.join(', ')}\n\n'
          'Tiada delivery baru untuk tuntutan. Sila pilih delivery yang belum dibuat tuntutan.');
    }

    // Get delivery items with quantities
    List deliveryItems = [];
    if (deliveryIds.isNotEmpty) {
    final itemsResponse = await supabase
        .from('vendor_delivery_items')
        .select('*')
        .filter('delivery_id', 'in', _buildInFilter(deliveryIds));
      deliveryItems = itemsResponse as List;
    }

    // Merge carry forward items as virtual delivery items (if any)
    if (carryForwardItems != null && carryForwardItems.isNotEmpty) {
      deliveryItems = [
        ...deliveryItems,
        ...carryForwardItems,
      ];
    }

    // Validate and auto-balance quantities
    final itemsToUpdate = <Map<String, dynamic>>[];
    for (var item in deliveryItems) {
      final itemMap = item as Map<String, dynamic>;
      final itemId = itemMap['id'] as String;
      final quantity = (itemMap['quantity'] as num?)?.toDouble() ?? 0.0;
      var sold = (itemMap['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      var unsold = (itemMap['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
      var expired = (itemMap['quantity_expired'] as num?)?.toDouble() ?? 0.0;
      var damaged = (itemMap['quantity_damaged'] as num?)?.toDouble() ?? 0.0;
      final total = sold + unsold + expired + damaged;

      bool needsUpdate = false;

      // If quantities not set, assume all are unsold
      if (total == 0 && quantity > 0) {
        unsold = quantity;
        itemMap['quantity_unsold'] = unsold;
        needsUpdate = true;
      } else if ((total - quantity).abs() > 0.01) {
        // If quantities don't balance, adjust unsold to make it balance
        final difference = quantity - total;
        if (difference > 0) {
          unsold = (unsold + difference).clamp(0.0, quantity);
          itemMap['quantity_unsold'] = unsold;
          needsUpdate = true;
        } else {
          throw Exception(
              'Quantities exceed delivered for item $itemId: delivered=$quantity, sum=$total');
        }
      }

      // Update database if needed
      if (needsUpdate) {
        itemsToUpdate.add({
          'id': itemId,
          'quantity_unsold': unsold,
        });
      }
    }

    // Batch update delivery items with balanced quantities
    if (itemsToUpdate.isNotEmpty) {
      for (var update in itemsToUpdate) {
        await supabase.from('vendor_delivery_items').update({
              'quantity_unsold': update['quantity_unsold'],
        }).eq('id', update['id']);
      }
    }

    // IMPORTANT: unit_price in delivery_items already has commission deducted
    // Delivery flow: retail_price - commission = unit_price (consignment price)
    // Claim flow: qty_sold × unit_price = claim amount (NO need to deduct commission again)
    
    // Calculate amounts - unit_price already is consignment price (after commission)
    double grossAmount = 0.0;
    
    for (var item in deliveryItems) {
      final itemMap = item as Map<String, dynamic>;
      final sold = (itemMap['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      final unitPrice = (itemMap['unit_price'] as num?)?.toDouble() ?? 0.0;
      // unit_price is already consignment price (retail - commission)
      final itemAmount = sold * unitPrice;
      grossAmount += itemAmount;
    }

    // Commission was already deducted in delivery, so commission_amount = 0
    final commissionAmount = 0.0;
    final netAmount = grossAmount; // net = gross because no commission deduction needed

    // Generate a unique claim_number on the client (per business_owner_id + month).
    // NOTE: This expects DB uniqueness to be (business_owner_id, claim_number),
    // as enforced by migration `db/migrations/fix_consignment_claim_number_per_owner.sql`.
    // Format: USER_PREFIX-CLM-YYMM-0001 or CLM-YYMM-0001 (if no user prefix)
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    
    // Get prefix from business_profile (format: "USER_PREFIX-CLM" or "CLM")
    final prefix = await _getClaimPrefix(userId);
    final prefixWithDash = '$prefix-$yy$mm-';
    int seqNum = await _getNextClaimSeqForMonth(
      userId: userId,
      prefixWithDash: prefixWithDash,
    );

    // Create claim - let trigger generate claim_number automatically
    // Retry logic to handle potential race conditions with claim_number generation
    Map<String, dynamic>? claimResponse;
    int retries = 10; // Increase retries untuk better success rate
    Exception? lastError;

    while (retries > 0) {
      final claimNumber = '$prefixWithDash${seqNum.toString().padLeft(4, '0')}';
      try {
        claimResponse = await supabase
        .from('consignment_claims')
        .insert({
          'business_owner_id': userId,
          'vendor_id': vendorId,
          'claim_date': claimDate.toIso8601String().split('T')[0],
          'claim_number': claimNumber, // Set explicitly to avoid trigger conflicts
          'status': 'draft',
          'gross_amount': grossAmount,
          'commission_rate': 0.0, // Commission already deducted in delivery, so 0 here
          'commission_amount': commissionAmount, // 0.0 - commission already deducted in delivery
          'net_amount': netAmount, // Same as gross_amount
          'paid_amount': 0,
          'balance_amount': netAmount,
          'notes': notes,
        })
        .select()
            .single() as Map<String, dynamic>;

        // Success - break retry loop
        break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        final errorStr = e.toString().toLowerCase();

        // Log real error details when available
        if (e is PostgrestException) {
          debugPrint(
              'PostgrestException creating claim (claim_number=$claimNumber): code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
        } else {
          debugPrint('Error creating claim (claim_number=$claimNumber): $e');
        }

        // Check for duplicate key error - Supabase returns 409 Conflict
        // Check multiple patterns: duplicate key, 23505, 409, claim_number_key, conflict
        // Also check for PostgrestException which Supabase uses
        final isDuplicateError = (e is PostgrestException && e.code == '23505') ||
            errorStr.contains('duplicate key') ||
            errorStr.contains('23505') ||
            errorStr.contains('409') ||
            errorStr.contains('claim_number') ||
            errorStr.contains('conflict') ||
            (e.toString().contains('PostgrestException') && errorStr.contains('unique'));

        if (isDuplicateError) {
          retries--;
          if (retries > 0) {
            // Exponential backoff: 300ms, 500ms, 700ms, 900ms, 1100ms, 1300ms, 1500ms, 1700ms, 1900ms, 2100ms
            final delayMs = 300 + (200 * (10 - retries));
            debugPrint('Retry attempt ${10 - retries + 1}/10 after ${delayMs}ms delay');
            await Future.delayed(Duration(milliseconds: delayMs));
            seqNum++; // try next claim number
            continue; // Retry
          } else {
            // All retries exhausted - throw user-friendly error with more details
            throw Exception(
                'Gagal mencipta tuntutan selepas ${10} percubaan. Nombor tuntutan mungkin konflik atau ada masalah dengan database. Sila cuba lagi dalam beberapa saat atau hubungi support jika masalah berterusan.');
          }
        }

        // If not duplicate key error, throw immediately
        rethrow;
      }
    }

    if (claimResponse == null) {
      throw Exception(
          'Gagal mencipta tuntutan: ${lastError?.toString() ?? "Ralat tidak diketahui"}');
    }

    final claimId = claimResponse['id'] as String;

    // Create claim items
    final claimItems = <Map<String, dynamic>>[];
    for (var item in deliveryItems) {
      final itemMap = item as Map<String, dynamic>;
      final sold = (itemMap['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      final unsold = (itemMap['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
      // Skip only if tiada jualan dan tiada baki/CF langsung
      if (sold <= 0 && unsold <= 0) continue;

      final unitPrice = (itemMap['unit_price'] as num?)?.toDouble() ?? 0.0;
      // unit_price is already consignment price (retail - commission), so no commission deduction needed
      final itemAmount = sold * unitPrice;
      final itemCommission = 0.0; // Commission already deducted in delivery
      final itemNet = itemAmount; // net = gross because no commission deduction

      claimItems.add({
        'claim_id': claimId,
        'delivery_id': itemMap['delivery_id'],
        'delivery_item_id': itemMap['id'],
        'quantity_delivered': itemMap['quantity'],
        'quantity_sold': sold,
        'quantity_unsold': itemMap['quantity_unsold'] ?? 0,
        'quantity_expired': itemMap['quantity_expired'] ?? 0,
        'quantity_damaged': itemMap['quantity_damaged'] ?? 0,
        'unit_price': unitPrice,
        'gross_amount': itemAmount,
        'commission_rate': 0.0, // Commission already deducted in delivery
        'commission_amount': itemCommission, // 0.0
        'net_amount': itemNet,
        'paid_amount': 0,
        'balance_amount': itemNet,
        'carry_forward_status': itemMetadata?[(itemMap['id'] as String)]
                ?['carry_forward_status'] ??
            'none',
        'carry_forward': (itemMetadata?[(itemMap['id'] as String)]
                    ?['carry_forward_status'] ??
                'none') ==
            'carry_forward',
      });
    }

    if (claimItems.isEmpty) {
      throw Exception('No items with sold quantity to claim');
    }

    await supabase.from('consignment_claim_items').insert(claimItems);

    // Return claim detail
    return await getClaimById(claimId);
  }

  /// Submit claim
  Future<ConsignmentClaim> submitClaim(String claimId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await supabase
        .from('consignment_claims')
        .update({
          'status': 'submitted',
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', claimId)
        .eq('business_owner_id', userId);

    return await getClaimById(claimId);
  }

  /// Approve claim
  Future<ConsignmentClaim> approveClaim(String claimId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await supabase
        .from('consignment_claims')
        .update({
          'status': 'approved',
          'approved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', claimId)
        .eq('business_owner_id', userId)
        .eq('status', 'submitted'); // Only approve submitted claims

    return await getClaimById(claimId);
  }

  /// Reject claim
  Future<ConsignmentClaim> rejectClaim(String claimId, String reason) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await supabase
        .from('consignment_claims')
        .update({
          'status': 'rejected',
          'notes': reason,
        })
        .eq('id', claimId)
        .eq('business_owner_id', userId);

    return await getClaimById(claimId);
  }

  /// List claims with filters
  Future<Map<String, dynamic>> listClaims({
    String? vendorId,
    ClaimStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    var query = supabase.from('consignment_claims').select('''
          *,
          vendors (id, name, phone)
        ''').eq('business_owner_id', userId);

    if (vendorId != null) {
      query = query.eq('vendor_id', vendorId);
    }
    if (status != null) {
      query = query.eq('status', status.toString().split('.').last);
    }
    if (fromDate != null) {
      query = query.gte('claim_date', fromDate.toIso8601String().split('T')[0]);
    }
    if (toDate != null) {
      query = query.lte('claim_date', toDate.toIso8601String().split('T')[0]);
    }

    final response = await query
        .order('claim_date', ascending: false)
        .range(offset, offset + limit - 1);

    final claims = (response as List).map((json) {
      final claimJson = json as Map<String, dynamic>;
      final vendor = claimJson['vendors'] as Map<String, dynamic>?;
      return ConsignmentClaim.fromJson({
        ...claimJson,
        'vendor_name': vendor?['name'],
      });
    }).toList();

    // Check if there are more
    final hasMore = claims.length == limit;

    return {
      'data': claims,
      'hasMore': hasMore,
      'total': offset + claims.length + (hasMore ? 1 : 0),
    };
  }

  /// Get claim by ID with items
  Future<List<ConsignmentClaim>> getAll({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final userId = SupabaseHelper.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase
          .from('consignment_claims')
          .select('''
            *,
            vendors (id, name, phone)
          ''')
          .eq('business_owner_id', userId)
          .order('claim_date', ascending: false)
          .range(offset, offset + limit - 1); // Add pagination

      return (response as List).map((json) {
        final claimJson = json as Map<String, dynamic>;
        final vendor = claimJson['vendors'] as Map<String, dynamic>?;
        
        // Flatten vendor data into claim JSON
        if (vendor != null) {
          claimJson['vendor_name'] = vendor['name'] as String? ?? '';
          claimJson['vendor_phone'] = vendor['phone'] as String?;
        }
        
        return ConsignmentClaim.fromJson(claimJson);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get claims: $e');
    }
  }

  /// Update claim item quantities
  Future<ConsignmentClaim> updateClaimItemQuantities({
    required String claimId,
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

    // Get claim item
    final itemResponse = await supabase
        .from('consignment_claim_items')
        .select('*')
        .eq('id', itemId)
        .eq('claim_id', claimId)
        .single();

    final item = itemResponse as Map<String, dynamic>;
    final quantityDelivered =
        (item['quantity_delivered'] as num?)?.toDouble() ?? 0.0;
    final total =
        quantitySold + quantityUnsold + quantityExpired + quantityDamaged;

    if ((total - quantityDelivered).abs() > 0.01) {
      throw Exception(
          'Quantities don\'t balance: delivered=$quantityDelivered, sum=$total');
    }

    // Update item
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final commissionRate = (item['commission_rate'] as num?)?.toDouble() ?? 0.0;
    final itemGross = quantitySold * unitPrice;
    final itemCommission = itemGross * (commissionRate / 100);
    final itemNet = itemGross - itemCommission;
    final paidAmount = (item['paid_amount'] as num?)?.toDouble() ?? 0.0;

    await supabase.from('consignment_claim_items').update({
          'quantity_sold': quantitySold,
          'quantity_unsold': quantityUnsold,
          'quantity_expired': quantityExpired,
          'quantity_damaged': quantityDamaged,
          'gross_amount': itemGross,
          'commission_amount': itemCommission,
          'net_amount': itemNet,
          'balance_amount': itemNet - paidAmount,
    }).eq('id', itemId);

    // Recalculate claim totals
    final allItemsResponse = await supabase
        .from('consignment_claim_items')
        .select('gross_amount, commission_amount, net_amount, paid_amount')
        .eq('claim_id', claimId);

    final allItems = allItemsResponse as List;
    double totalGross = 0.0;
    double totalCommission = 0.0;
    double totalNet = 0.0;
    double totalPaid = 0.0;

    for (var item in allItems) {
      final itemMap = item as Map<String, dynamic>;
      totalGross += (itemMap['gross_amount'] as num?)?.toDouble() ?? 0.0;
      totalCommission +=
          (itemMap['commission_amount'] as num?)?.toDouble() ?? 0.0;
      totalNet += (itemMap['net_amount'] as num?)?.toDouble() ?? 0.0;
      totalPaid += (itemMap['paid_amount'] as num?)?.toDouble() ?? 0.0;
    }

    await supabase.from('consignment_claims').update({
          'gross_amount': totalGross,
          'commission_amount': totalCommission,
          'net_amount': totalNet,
          'balance_amount': totalNet - totalPaid,
    }).eq('id', claimId);

    return await getClaimById(claimId);
  }

  // ============================================================================
  // NEW METHODS - For Simplified UI
  // ============================================================================

  /// Validate claim request before creating
  /// Returns clear feedback about what's wrong
  Future<ClaimValidationResult> validateClaimRequest({
    required String vendorId,
    required List<String> deliveryIds,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      return ClaimValidationResult(
        isValid: false,
        errors: ['Anda perlu log masuk untuk menuntut bayaran'],
      );
    }

    final errors = <String>[];
    final warnings = <String>[];

    // Check vendor selected
    if (vendorId.isEmpty) {
      errors.add('Sila pilih vendor');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Check deliveries selected
    if (deliveryIds.isEmpty) {
      errors.add('Sila pilih sekurang-kurangnya satu penghantaran');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    String _buildInFilter(List<String> values) =>
        '(${values.map((v) => '"$v"').join(',')})';

    // Validate vendor exists
    final vendorResponse = await supabase
        .from('vendors')
        .select('id, name, default_commission_rate')
        .eq('id', vendorId)
        .eq('business_owner_id', userId)
        .maybeSingle();

    if (vendorResponse == null) {
      errors.add('Vendor tidak dijumpai. Sila pilih vendor yang betul.');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Validate deliveries exist and belong to vendor
    final deliveriesResponse = await supabase
        .from('vendor_deliveries')
        .select('id, vendor_id, vendor_name, status')
        .filter('id', 'in', _buildInFilter(deliveryIds))
        .eq('business_owner_id', userId);

    final deliveries = deliveriesResponse as List;
    if (deliveries.length != deliveryIds.length) {
      final missing = deliveryIds.length - deliveries.length;
      errors.add('$missing penghantaran tidak dijumpai. Sila semak semula.');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Check all deliveries are for same vendor
    final vendorIds =
        deliveries.map((d) => (d as Map)['vendor_id'] as String).toSet();
    if (vendorIds.length > 1 || !vendorIds.contains(vendorId)) {
      errors.add('Semua penghantaran mesti untuk vendor yang sama');
      return ClaimValidationResult(isValid: false, errors: errors);
    }

    // Check deliveries have items with sold quantity
    final itemsResponse = await supabase
        .from('vendor_delivery_items')
        .select('*')
        .filter('delivery_id', 'in', _buildInFilter(deliveryIds));

    final deliveryItems = itemsResponse as List;
    final itemsWithSold = deliveryItems.where((item) {
      final sold = ((item as Map<String, dynamic>)['quantity_sold'] as num?)
              ?.toDouble() ??
          0.0;
      return sold > 0;
    }).toList();

    if (itemsWithSold.isEmpty) {
      errors.add(
          'Tiada produk yang terjual untuk dituntut. Sila pastikan vendor telah update kuantiti terjual.');
      warnings.add(
          'Tip: Vendor perlu update kuantiti terjual dalam sistem sebelum anda boleh buat tuntutan');
      return ClaimValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    return ClaimValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Get summary of claim amounts before creating
  /// Helps user understand what they're claiming
  Future<ClaimSummary> getClaimSummary({
    required String vendorId,
    required List<String> deliveryIds,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    String _buildInFilter(List<String> values) =>
        '(${values.map((v) => '"$v"').join(',')})';

    // Get vendor commission rate
    final vendorResponse = await supabase
        .from('vendors')
        .select('default_commission_rate')
        .eq('id', vendorId)
        .eq('business_owner_id', userId)
        .maybeSingle();

    final commissionRate = ((vendorResponse
                as Map<String, dynamic>?)?['default_commission_rate'] as num?)
            ?.toDouble() ??
        0.0;

    // Get delivery items
    final itemsResponse = await supabase
        .from('vendor_delivery_items')
        .select('*')
        .filter('delivery_id', 'in', _buildInFilter(deliveryIds));

    final deliveryItems = (itemsResponse as List).cast<Map<String, dynamic>>();

    // Auto-balance quantities if needed
    final itemsToUpdate = <Map<String, dynamic>>[];
    for (var item in deliveryItems) {
      final itemId = item['id'] as String;
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      var sold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      var unsold = (item['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
      var expired = (item['quantity_expired'] as num?)?.toDouble() ?? 0.0;
      var damaged = (item['quantity_damaged'] as num?)?.toDouble() ?? 0.0;
      final total = sold + unsold + expired + damaged;

      bool needsUpdate = false;

      // If quantities not set, assume all are unsold
      if (total == 0 && quantity > 0) {
        unsold = quantity;
        needsUpdate = true;
      } else if ((total - quantity).abs() > 0.01) {
        // If quantities don't balance, adjust unsold
        final difference = quantity - total;
        if (difference > 0) {
          unsold = (unsold + difference).clamp(0.0, quantity);
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        itemsToUpdate.add({
          'id': itemId,
          'quantity_unsold': unsold,
        });
        // Update in-memory data
        item['quantity_unsold'] = unsold;
      }
    }

    // Calculate summary
    return ClaimSummary.fromDeliveryItems(
      deliveryItems: deliveryItems,
      commissionRate: commissionRate,
    );
  }

  /// Update payment amount for a claim
  /// This updates paid_amount and automatically recalculates balance_amount
  Future<ConsignmentClaim> updateClaimPayment({
    required String claimId,
    required double paidAmount, // treated as increment (add-on)
    DateTime? paymentDate,
    String? paymentReference,
    String? notes,
  }) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get current claim to validate
    final claimResponse = await supabase
        .from('consignment_claims')
        .select('id, net_amount, paid_amount, balance_amount, status')
        .eq('id', claimId)
        .eq('business_owner_id', userId)
        .maybeSingle();

    if (claimResponse == null) {
      throw Exception('Claim not found');
    }

    final claim = claimResponse as Map<String, dynamic>;
    final netAmount = (claim['net_amount'] as num?)?.toDouble() ?? 0.0;
    final currentPaid = (claim['paid_amount'] as num?)?.toDouble() ?? 0.0;

    final newPaid = currentPaid + paidAmount;

    // Validate new paid amount doesn't exceed net amount
    if (newPaid - netAmount > 0.01) {
      throw Exception(
          'Jumlah bayaran tidak boleh melebihi jumlah tuntutan (RM ${netAmount.toStringAsFixed(2)})');
    }

    // Calculate new balance
    final newBalance = netAmount - newPaid;

    // Update claim with new paid amount
    // Database trigger will automatically update balance_amount
    final updateData = <String, dynamic>{
      'paid_amount': newPaid,
      'balance_amount': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Update status to settled if fully paid
    if (newPaid >= netAmount - 0.0001) {
      updateData['status'] = 'settled';
      updateData['settled_at'] = DateTime.now().toIso8601String();
    } else if (paidAmount > 0) {
      // Keep existing status if already approved/submitted
      updateData['status'] = claim['status'];
    }

    // Add optional fields
    if (paymentDate != null) {
      // Store payment date in notes or separate field if needed
      // For now, we'll use notes field
    }
    if (paymentReference != null || notes != null) {
      final existingNotes = claim['notes'] as String? ?? '';
      final newNotes = [
        if (existingNotes.isNotEmpty) existingNotes,
        if (paymentReference != null) 'Rujukan: $paymentReference',
        if (notes != null) notes,
      ].join('\n');
      updateData['notes'] = newNotes;
    }

    await supabase
        .from('consignment_claims')
        .update(updateData)
        .eq('id', claimId)
        .eq('business_owner_id', userId);

    // Return updated claim
    return await getClaimById(claimId);
  }

  /// Get delivery IDs that have already been claimed (approved, submitted, or settled)
  /// Note: We exclude 'draft' status as those claims can still be edited/deleted
  Future<Set<String>> getClaimedDeliveryIds(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get all claims for this vendor (including draft)
      // This prevents duplicate claims for the same delivery
      // Draft claims can still be edited but should still block new claims for same delivery
      final claimsResponse = await supabase
          .from('consignment_claims')
          .select('id, status')
          .eq('business_owner_id', userId)
          .eq('vendor_id', vendorId)
          .inFilter('status',
              ['draft', 'submitted', 'approved', 'settled', 'rejected']);

      final claims = claimsResponse as List;
      if (claims.isEmpty) {
        return <String>{}; // No claims, so no claimed deliveries
      }

      // Get claim IDs
      final claimIds = claims
          .map((c) => (c as Map<String, dynamic>)['id'] as String)
          .toList();

      if (claimIds.isEmpty) {
        return <String>{};
      }

      // Get all claim items for these claims using inFilter
      final itemsResponse = await supabase
          .from('consignment_claim_items')
          .select('delivery_id')
          .inFilter('claim_id', claimIds);

      // Get unique delivery IDs (filter out nulls in code)
      final deliveryIds = <String>{};
      for (var item in itemsResponse as List) {
        final itemMap = item as Map<String, dynamic>;
        final deliveryId = itemMap['delivery_id'] as String?;
        if (deliveryId != null && deliveryId.isNotEmpty) {
          deliveryIds.add(deliveryId);
        }
      }

      // Debug output
      print('🔍 Found ${claims.length} non-draft claims for vendor $vendorId');
      print(
          '🔍 Found ${deliveryIds.length} unique claimed delivery IDs: ${deliveryIds.toList()}');

      return deliveryIds;
    } catch (e, stackTrace) {
      // Log error but don't throw - return empty set so UI can still work
      // The validation in createClaim will catch duplicates anyway
      print('⚠️ Error getting claimed delivery IDs: $e');
      print('Stack trace: $stackTrace');
      return <String>{};
    }
  }

  /// Get claims by vendor ID
  Future<List<ConsignmentClaim>> getClaimsByVendor(String vendorId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase
        .from('consignment_claims')
        .select('''
          *,
          vendors (id, name, phone)
        ''')
        .eq('business_owner_id', userId)
        .eq('vendor_id', vendorId)
        .order('claim_date', ascending: false);

    return (response as List).map((json) {
      final claimJson = json as Map<String, dynamic>;
      final vendor = claimJson['vendors'] as Map<String, dynamic>?;
      return ConsignmentClaim.fromJson({
        ...claimJson,
        'vendor_name': vendor?['name'],
      });
    }).toList();
  }

  /// Get claim by ID
  Future<ConsignmentClaim> getClaimById(String claimId) async {
    final userId = SupabaseHelper.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase.from('consignment_claims').select('''
          *,
          vendors (id, name, phone),
          consignment_claim_items (
            *,
            delivery:vendor_deliveries (
              invoice_number
            ),
            delivery_item:vendor_delivery_items (
              product_id,
              product_name,
              unit_price
            )
          )
        ''').eq('id', claimId).eq('business_owner_id', userId).single();

    // Get carry forward items used in this claim to identify C/F items
    final cfDeliveryItemIds = <String>{}; // Track which delivery_item_ids are from C/F
    final cfDeliveryIds = <String>{}; // Track which delivery_ids are from C/F
    final cfClaimNumbers = <String, String>{}; // Map delivery_item_id to original claim number
    
    try {
      final cfItemsResponse = await supabase
          .from('carry_forward_items')
          .select('source_delivery_id, source_delivery_item_id, original_claim_number')
          .eq('used_in_claim_id', claimId)
          .eq('status', 'used');
      
      final cfItems = (cfItemsResponse as List).cast<Map<String, dynamic>>();
      
      for (var cfItem in cfItems) {
        final deliveryId = cfItem['source_delivery_id'] as String?;
        final deliveryItemId = cfItem['source_delivery_item_id'] as String?;
        final claimNumber = cfItem['original_claim_number'] as String?;
        
        if (deliveryId != null && deliveryId.isNotEmpty) {
          cfDeliveryIds.add(deliveryId);
        }
        if (deliveryItemId != null && deliveryItemId.isNotEmpty) {
          cfDeliveryItemIds.add(deliveryItemId);
          if (claimNumber != null && claimNumber.isNotEmpty) {
            cfClaimNumbers[deliveryItemId] = claimNumber;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading carry forward items: $e');
      // Continue without C/F info if there's an error
    }

    final claimJson = response as Map<String, dynamic>;
    final vendor = claimJson['vendors'] as Map<String, dynamic>?;

    // Process items to extract delivery_number and product_name from joins
    final items = claimJson['consignment_claim_items'] as List<dynamic>?;
    final processedItems = items?.map((item) {
      final itemMap = item as Map<String, dynamic>;
      final delivery = itemMap['delivery'] as Map<String, dynamic>?;
      final deliveryItem = itemMap['delivery_item'] as Map<String, dynamic>?;
      final deliveryItemId = itemMap['delivery_item_id'] as String?;
      final deliveryId = itemMap['delivery_id'] as String?;

      // Extract product_name from delivery_item (priority) or from item itself
      final productName = deliveryItem?['product_name'] as String? ??
          itemMap['product_name'] as String? ??
          'Unknown Product';

      // Check if this item is from carry forward
      final isFromCarryForward = (deliveryItemId != null && cfDeliveryItemIds.contains(deliveryItemId)) ||
          (deliveryId != null && cfDeliveryIds.contains(deliveryId));

      return {
        ...itemMap,
        'delivery_number': delivery?['invoice_number'] as String?,
        'product_name': productName, // Ensure product_name is set
        'product_id': deliveryItem?['product_id'] ?? itemMap['product_id'],
        'unit_price': deliveryItem?['unit_price'] ?? itemMap['unit_price'],
        'is_carry_forward': isFromCarryForward, // Add flag for C/F items
      };
    }).toList();

    return ConsignmentClaim.fromJson({
      ...claimJson,
      'vendor_name': vendor?['name'] as String? ?? '',
      'items': processedItems,
    });
  }
}
