import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/consignment_claim.dart';
import 'consignment_claims_repository_supabase.dart';

/// Cached version of ConsignmentClaimsRepository dengan Stale-While-Revalidate
///
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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

    // Use direct Hive caching untuk List types (more reliable - no type casting issues)
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final jsonList = jsonDecode(cached) as List<dynamic>;
          final claims = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return ConsignmentClaim.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${claims.length} claims');
          
          // Trigger background sync
          _syncClaimsInBackground(
            userId: userId,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return claims;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached claims: $e');
      }
    }

    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchClaims(
      userId: userId,
      limit: limit,
      offset: offset,
    );

    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((c) => c.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('consignment_claims');
      debugPrint('✅ Cached ${fresh.length} claims');
    } catch (e) {
      debugPrint('⚠️ Error caching claims: $e');
    }

    return fresh;
  }

  /// Fetch claims from Supabase
  Future<List<ConsignmentClaim>> _fetchClaims({
    required String userId,
    int limit = 100,
    int offset = 0,
  }) async {
    // Build query dengan delta fetch support
    final lastSync =
        await PersistentCacheService.getLastSync('consignment_claims');
    
    // Build base query
    dynamic query = supabase
        .from('consignment_claims')
        .select('''
          *,
          vendors (id, name, phone)
        ''')
        .eq('business_owner_id', userId);
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint(
          '🔄 Delta fetch: consignment_claims updated after ${lastSync.toIso8601String()}');
    }
    
    // Order must be after filters
    query = query.order('claim_date', ascending: false);
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.range(offset, offset + limit - 1);
    }
    
    // Execute query
    final queryResult = await query;
    final rawData = List<dynamic>.from(queryResult);
    final processedData = _processClaimsData(rawData);
    
    // If delta fetch returns empty, do full fetch
    if (processedData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full consignment_claims list');
      // Full fetch
      final fullResult = await supabase
          .from('consignment_claims')
          .select('''
            *,
            vendors (id, name, phone)
          ''')
          .eq('business_owner_id', userId)
          .order('claim_date', ascending: false)
          .range(offset, offset + limit - 1);
      
      final fullProcessed = _processClaimsData(fullResult as List<dynamic>);
      return fullProcessed.map((json) {
        return ConsignmentClaim.fromJson(json);
      }).toList();
    }

    return processedData.map((json) {
      return ConsignmentClaim.fromJson(json);
    }).toList();
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

  /// Background sync for claims
  Future<void> _syncClaimsInBackground({
    required String userId,
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<ConsignmentClaim>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchClaims(
        userId: userId,
        limit: limit,
        offset: offset,
      );

      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((c) => c.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('consignment_claims');
      } catch (e) {
        debugPrint('⚠️ Error updating claims cache: $e');
      }

      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} claims');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }

  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
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
    try {
      // Clear common claims cache boxes
      final commonKeys = ['consignment_claims_0_100', 'consignment_claims_100_100', 'consignment_claims'];
      for (final key in commonKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            await Hive.box(key).clear();
          }
        } catch (e) {
          // Box might not exist, ignore
        }
      }
      debugPrint('✅ Claims cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating claims cache: $e');
    }
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
