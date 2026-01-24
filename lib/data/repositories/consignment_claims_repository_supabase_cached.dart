import 'package:flutter/foundation.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/consignment_claim.dart';
import 'consignment_claims_repository_supabase.dart';

/// Cached version of ConsignmentClaimsRepository dengan Stale-While-Revalidate
///
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
///
/// Priority: MEDIUM (Used in consignment workflow)
class ConsignmentClaimsRepositorySupabaseCached {
  final ConsignmentClaimsRepositorySupabase _baseRepo =
      ConsignmentClaimsRepositorySupabase();

  /// Get all claims dengan persistent cache + Stale-While-Revalidate
  ///
  /// Returns cached data immediately, syncs in background
  Future<List<ConsignmentClaim>> getAllCached({
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<ConsignmentClaim>)? onDataUpdated,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Build cache key dengan pagination
    final cacheKey = 'consignment_claims_${offset}_$limit';

    return await PersistentCacheService.getOrSync<List<ConsignmentClaim>>(
      key: cacheKey,
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync =
            await PersistentCacheService.getLastSync('consignment_claims');
        var query = supabase
            .from('consignment_claims')
            .select('''
              *,
              vendors (id, name, phone)
            ''')
            .eq('business_owner_id', userId)
            .order('claim_date', ascending: false);

        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint(
              '🔄 Delta fetch: consignment_claims updated after ${lastSync.toIso8601String()}');
        } else {
          // Full fetch with pagination
          query = query.range(offset, offset + limit - 1);
        }

        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full consignment_claims list');
          // Full fetch
          final fullData = await supabase
              .from('consignment_claims')
              .select('''
                *,
                vendors (id, name, phone)
              ''')
              .eq('business_owner_id', userId)
              .order('claim_date', ascending: false)
              .range(offset, offset + limit - 1);
          return _processClaimsData(fullData);
        }

        return _processClaimsData(deltaData);
      },
      fromJson: (json) => ConsignmentClaim.fromJson(json),
      toJson: (claim) => claim.toJson(),
      onDataUpdated: onDataUpdated,
      forceRefresh: forceRefresh,
    );
  }

  /// Process raw claims data from Supabase
  List<Map<String, dynamic>> _processClaimsData(List<dynamic> rawData) {
    return rawData.map((json) {
      final claimJson = json as Map<String, dynamic>;
      final vendor = claimJson['vendors'] as Map<String, dynamic>?;

      // Flatten vendor data into claim JSON
      if (vendor != null) {
        claimJson['vendor_name'] = vendor['name'] as String? ?? '';
        claimJson['vendor_phone'] = vendor['phone'] as String?;
      }

      return claimJson;
    }).toList();
  }

  /// List claims with filters dan cache
  Future<Map<String, dynamic>> listClaimsCached({
    String? vendorId,
    ClaimStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<ConsignmentClaim>)? onDataUpdated,
  }) async {
    // For filtered queries, use base repo directly
    // Caching filtered queries is complex and less beneficial
    return await _baseRepo.listClaims(
      vendorId: vendorId,
      status: status,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
    );
  }

  /// Get claim by ID dengan cache
  Future<ConsignmentClaim> getClaimByIdCached(String claimId) async {
    // For single claim, use base repo (less caching benefit)
    return await _baseRepo.getClaimById(claimId);
  }

  /// Force refresh semua claims dari Supabase
  Future<List<ConsignmentClaim>> refreshAll({
    int limit = 100,
    int offset = 0,
  }) async {
    return await getAllCached(
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }

  /// Sync claims in background (non-blocking)
  Future<void> syncInBackground({
    int limit = 100,
    int offset = 0,
    void Function(List<ConsignmentClaim>)? onDataUpdated,
  }) async {
    try {
      await getAllCached(
        limit: limit,
        offset: offset,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: consignment_claims');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }

  /// Invalidate claims cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('consignment_claims');
  }

  // ============================================================================
  // Delegate methods to base repo (these modify data, so no caching)
  // ============================================================================

  Future<ConsignmentClaim> createClaim({
    required String vendorId,
    required List<String> deliveryIds,
    required DateTime claimDate,
    String? notes,
    Map<String, Map<String, dynamic>>? itemMetadata,
    List<Map<String, dynamic>>? carryForwardItems,
  }) async {
    final result = await _baseRepo.createClaim(
      vendorId: vendorId,
      deliveryIds: deliveryIds,
      claimDate: claimDate,
      notes: notes,
      itemMetadata: itemMetadata,
      carryForwardItems: carryForwardItems,
    );
    await invalidateCache(); // Invalidate after create
    return result;
  }

  Future<ConsignmentClaim> submitClaim(String claimId) async {
    final result = await _baseRepo.submitClaim(claimId);
    await invalidateCache();
    return result;
  }

  Future<ConsignmentClaim> approveClaim(String claimId) async {
    final result = await _baseRepo.approveClaim(claimId);
    await invalidateCache();
    return result;
  }

  Future<ConsignmentClaim> rejectClaim(String claimId, String reason) async {
    final result = await _baseRepo.rejectClaim(claimId, reason);
    await invalidateCache();
    return result;
  }

  Future<ConsignmentClaim> updateClaimPayment({
    required String claimId,
    required double paidAmount,
    DateTime? paymentDate,
    String? paymentReference,
    String? notes,
  }) async {
    final result = await _baseRepo.updateClaimPayment(
      claimId: claimId,
      paidAmount: paidAmount,
      paymentDate: paymentDate,
      paymentReference: paymentReference,
      notes: notes,
    );
    await invalidateCache();
    return result;
  }
}
