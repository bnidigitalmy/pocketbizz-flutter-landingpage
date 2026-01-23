import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'persistent_cache_service.dart';

/// Service untuk sync data dari Supabase dengan delta fetch
/// 
/// Features:
/// - Delta fetch (hanya ambil data yang updated selepas last_sync)
/// - Automatic retry on failure
/// - Network-aware (skip sync kalau offline)
/// 
/// Usage:
/// ```dart
/// final syncService = SyncService();
/// await syncService.syncTable('products', (query) {
///   return query.select();
/// });
/// ```
class SyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Sync table dengan delta fetch
  /// 
  /// [tableName] - Nama table di Supabase
  /// [queryBuilder] - Function untuk build query (akan tambah .gt('updated_at') automatically)
  /// [forceFullSync] - Skip delta dan fetch semua (default: false)
  /// 
  /// Returns: List of updated records
  Future<List<Map<String, dynamic>>> syncTable({
    required String tableName,
    required List<Map<String, dynamic>> Function(PostgrestQueryBuilder) queryBuilder,
    bool forceFullSync = false,
  }) async {
    try {
      var query = _supabase.from(tableName);
      
      // Delta fetch: hanya ambil records yang updated selepas last sync
      if (!forceFullSync) {
        final lastSync = await PersistentCacheService.getLastSync(tableName);
        if (lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta sync for $tableName: fetching records updated after ${lastSync.toIso8601String()}');
        } else {
          debugPrint('🔄 Full sync for $tableName: no previous sync found');
        }
      } else {
        debugPrint('🔄 Force full sync for $tableName');
      }
      
      // Execute query
      final data = queryBuilder(query);
      
      debugPrint('✅ Sync completed for $tableName: ${data.length} records');
      return data;
      
    } catch (e) {
      debugPrint('❌ Sync failed for $tableName: $e');
      rethrow;
    }
  }
  
  /// Sync multiple tables in parallel
  /// 
  /// [tables] - Map of tableName -> queryBuilder function
  /// 
  /// Returns: Map of tableName -> List of records
  Future<Map<String, List<Map<String, dynamic>>>> syncMultiple({
    required Map<String, List<Map<String, dynamic>> Function(PostgrestQueryBuilder)> tables,
    bool forceFullSync = false,
  }) async {
    final results = <String, List<Map<String, dynamic>>>{};
    
    // Sync all tables in parallel
    final futures = tables.entries.map((entry) async {
      try {
        final data = await syncTable(
          tableName: entry.key,
          queryBuilder: entry.value,
          forceFullSync: forceFullSync,
        );
        return MapEntry(entry.key, data);
      } catch (e) {
        debugPrint('⚠️ Failed to sync ${entry.key}: $e');
        return MapEntry(entry.key, <Map<String, dynamic>>[]);
      }
    });
    
    final completed = await Future.wait(futures);
    for (final entry in completed) {
      results[entry.key] = entry.value;
    }
    
    return results;
  }
  
  /// Check if network is available
  /// (Simple check - can be enhanced with connectivity_plus package)
  Future<bool> isNetworkAvailable() async {
    try {
      // Try to ping Supabase
      await _supabase.from('products').select('id').limit(1).maybeSingle();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Sync dengan retry logic
  /// 
  /// [tableName] - Nama table
  /// [queryBuilder] - Query builder function
  /// [maxRetries] - Maximum retry attempts (default: 3)
  /// [retryDelay] - Delay between retries (default: 2 seconds)
  Future<List<Map<String, dynamic>>> syncWithRetry({
    required String tableName,
    required List<Map<String, dynamic>> Function(PostgrestQueryBuilder) queryBuilder,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    bool forceFullSync = false,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await syncTable(
          tableName: tableName,
          queryBuilder: queryBuilder,
          forceFullSync: forceFullSync,
        );
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          debugPrint('❌ Sync failed after $maxRetries attempts for $tableName');
          rethrow;
        }
        
        debugPrint('⚠️ Sync attempt $attempts failed for $tableName, retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
      }
    }
    
    throw Exception('Sync failed after $maxRetries attempts');
  }
}

