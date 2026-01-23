import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache service dengan Stale-While-Revalidate pattern
/// 
/// Features:
/// - Load dari Hive (persistent storage) untuk instant render
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// Usage:
/// ```dart
/// final products = await PersistentCacheService.getOrSync<List<Product>>(
///   'products',
///   fetcher: () => _repo.getAllProducts(),
///   fromJson: (json) => Product.fromJson(json),
///   toJson: (product) => product.toJson(),
/// );
/// ```
class PersistentCacheService {
  static bool _initialized = false;
  static const String _lastSyncPrefix = 'last_sync_';
  static const String _syncInProgressPrefix = 'sync_in_progress_';
  
  /// Initialize Hive boxes (call once in main.dart)
  static Future<void> initialize() async {
    if (_initialized) return;
    
    await Hive.initFlutter();
    
    // Open boxes for different data types
    // Box names should match table names or data types
    await Future.wait([
      _openBoxIfNotExists('products'),
      _openBoxIfNotExists('sales'),
      _openBoxIfNotExists('expenses'),
      _openBoxIfNotExists('inventory'),
      _openBoxIfNotExists('vendors'),
      _openBoxIfNotExists('stock_items'),
      _openBoxIfNotExists('dashboard_stats'),
      // High priority modules
      _openBoxIfNotExists('categories'),
      _openBoxIfNotExists('suppliers'),
      _openBoxIfNotExists('deliveries'),
      _openBoxIfNotExists('bookings'),
      _openBoxIfNotExists('purchase_orders'),
      // Additional boxes for filtered queries
      _openBoxIfNotExists('sales_all'),
      _openBoxIfNotExists('expenses_0_50'),
      _openBoxIfNotExists('vendors_active'),
    ]);
    
    _initialized = true;
    debugPrint('✅ PersistentCacheService initialized');
  }
  
  static Future<Box> _openBoxIfNotExists(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox(boxName);
    }
    return Hive.box(boxName);
  }
  
  /// Get data dengan Stale-While-Revalidate pattern
  /// 
  /// 1. Return stale data immediately (from Hive)
  /// 2. Trigger background sync
  /// 3. Update UI silently if new data arrives
  /// 
  /// [key] - Cache key (usually table name)
  /// [fetcher] - Function to fetch fresh data from Supabase
  /// [fromJson] - Convert JSON to single item (e.g., Product.fromJson)
  /// [toJson] - Convert single item to JSON (e.g., product.toJson)
  /// [onDataUpdated] - Callback when fresh data arrives (optional)
  /// [forceRefresh] - Skip cache and fetch fresh (default: false)
  /// 
  /// For List types: T should be List<ItemType>, and fromJson should parse ItemType
  static Future<T> getOrSync<T>({
    required String key,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
    required dynamic Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(dynamic) toJson,
    void Function(T)? onDataUpdated,
    bool forceRefresh = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    
    final box = await _openBoxIfNotExists(key);
    
    // 1. STALE: Return cached data immediately (if exists and not forcing refresh)
    if (!forceRefresh && box.isNotEmpty) {
      try {
        final cachedData = _loadFromBox<T>(box, fromJson);
        debugPrint('✅ Cache hit (stale): $key - ${_getItemCount(cachedData)} items');
        
        // 2. REVALIDATE: Trigger background sync (non-blocking)
        _syncInBackground(
          key: key,
          fetcher: fetcher,
          fromJson: fromJson,
          toJson: toJson,
          onDataUpdated: onDataUpdated,
        );
        
        return cachedData;
      } catch (e) {
        debugPrint('⚠️ Error loading cache for $key: $e');
        // Fall through to fetch fresh data
      }
    }
    
    // 3. CACHE MISS: Fetch fresh data (blocking, first time load)
    debugPrint('🔄 Cache miss: $key - fetching fresh data...');
    final freshData = await fetcher();
    final parsedData = _parseData<T>(freshData, fromJson);
    
    // Store in cache
    await _saveToBox(box, parsedData, toJson);
    await _updateLastSync(key);
    
    debugPrint('✅ Fresh data cached: $key - ${_getItemCount(parsedData)} items');
    return parsedData;
  }
  
  /// Background sync (non-blocking)
  static Future<void> _syncInBackground<T>({
    required String key,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
    required dynamic Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(dynamic) toJson,
    void Function(T)? onDataUpdated,
  }) async {
    // Prevent multiple simultaneous syncs
    final prefs = await SharedPreferences.getInstance();
    final syncKey = '$_syncInProgressPrefix$key';
    if (prefs.getBool(syncKey) == true) {
      debugPrint('⏸️ Sync already in progress for $key');
      return;
    }
    
    await prefs.setBool(syncKey, true);
    
    try {
      final freshData = await fetcher();
      final box = await _openBoxIfNotExists(key);
      final parsedData = _parseData<T>(freshData, fromJson);
      
      // Check if data changed
      final cachedData = _loadFromBox<T>(box, fromJson);
      if (_hasChanges(parsedData, cachedData)) {
        await _saveToBox(box, parsedData, toJson);
        await _updateLastSync(key);
        
        debugPrint('🔄 Background sync completed: $key - data updated');
        
        // Notify UI if callback provided
        if (onDataUpdated != null) {
          onDataUpdated(parsedData);
        }
      } else {
        debugPrint('✅ Background sync: $key - no changes');
      }
    } catch (e) {
      debugPrint('❌ Background sync failed for $key: $e');
      // Don't throw - this is background operation
    } finally {
      await prefs.setBool(syncKey, false);
    }
  }
  
  /// Delta fetch - only get records updated after last sync
  /// 
  /// Usage in repository:
  /// ```dart
  /// final lastSync = await PersistentCacheService.getLastSync('products');
  /// final query = supabase.from('products');
  /// if (lastSync != null) {
  ///   query = query.gt('updated_at', lastSync.toIso8601String());
  /// }
  /// return await query.select();
  /// ```
  static Future<DateTime?> getLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('$_lastSyncPrefix$key');
    if (lastSyncStr == null) return null;
    
    try {
      return DateTime.parse(lastSyncStr);
    } catch (e) {
      debugPrint('⚠️ Error parsing last sync for $key: $e');
      return null;
    }
  }
  
  static Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_lastSyncPrefix$key', DateTime.now().toIso8601String());
  }
  
  /// Load data from Hive box
  static T _loadFromBox<T>(Box box, dynamic Function(Map<String, dynamic>) fromJson) {
    final List<dynamic> items = box.values.toList();
    
    // Check if T is a List type by checking the function signature
    // For List<Product>, we need to parse each item
    try {
      // Try to parse as List first
      final parsed = items.map((item) {
        if (item is String) {
          return fromJson(jsonDecode(item));
        } else if (item is Map) {
          return fromJson(item as Map<String, dynamic>);
        }
        throw Exception('Unexpected cache format');
      }).toList();
      
      // If we got here, it's likely a List type
      // Return as T (caller will handle type casting)
      return parsed as T;
    } catch (e) {
      // If parsing as List fails, try single object
      if (items.isEmpty) {
        throw Exception('Cache is empty');
      }
      final item = items.first;
      if (item is String) {
        return fromJson(jsonDecode(item));
      } else if (item is Map) {
        return fromJson(item as Map<String, dynamic>);
      }
      throw Exception('Unexpected cache format: $e');
    }
  }
  
  /// Save data to Hive box
  static Future<void> _saveToBox<T>(
    Box box,
    T data,
    Map<String, dynamic> Function(dynamic) toJson,
  ) async {
    await box.clear();
    
    if (data is List) {
      // Store each item with its ID as key (if available)
      for (var item in data) {
        final json = toJson(item);
        final id = json['id']?.toString() ?? json['id']?.toString();
        
        if (id != null) {
          await box.put(id, jsonEncode(json));
        } else {
          // No ID, use index
          await box.add(jsonEncode(json));
        }
      }
    } else {
      // Single object
      final json = toJson(data);
      await box.put('single', jsonEncode(json));
    }
  }
  
  /// Parse fetched data
  static T _parseData<T>(
    List<Map<String, dynamic>> data,
    dynamic Function(Map<String, dynamic>) fromJson,
  ) {
    // For List types, parse each item
    try {
      final parsed = data.map((json) => fromJson(json)).toList();
      return parsed as T;
    } catch (e) {
      // If that fails, try single object
      if (data.isEmpty) {
        throw Exception('No data returned');
      }
      return fromJson(data.first);
    }
  }
  
  /// Check if data has changed (simple comparison)
  static bool _hasChanges<T>(T newData, T oldData) {
    // Simple comparison - can be enhanced with deep equality
    return newData != oldData;
  }
  
  /// Get item count for logging
  static int _getItemCount<T>(T data) {
    if (data is List) {
      return data.length;
    }
    return 1;
  }
  
  /// Invalidate cache for specific key
  static Future<void> invalidate(String key) async {
    final box = await _openBoxIfNotExists(key);
    await box.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_lastSyncPrefix$key');
    
    debugPrint('🗑️ Cache invalidated: $key');
  }
  
  /// Invalidate multiple cache keys
  static Future<void> invalidateMultiple(List<String> keys) async {
    await Future.wait(keys.map((key) => invalidate(key)));
  }
  
  /// Clear all cache
  static Future<void> clearAll() async {
    final boxes = [
      'products',
      'sales',
      'expenses',
      'inventory',
      'vendors',
      'stock_items',
      'dashboard_stats',
      'categories',
      'suppliers',
      'deliveries',
      'bookings',
      'purchase_orders',
    ];
    
    await Future.wait(boxes.map((boxName) async {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
      }
    }));
    
    final prefs = await SharedPreferences.getInstance();
    for (final key in boxes) {
      await prefs.remove('$_lastSyncPrefix$key');
    }
    
    debugPrint('🗑️ All persistent cache cleared');
  }
  
  /// Get cache statistics
  static Future<Map<String, dynamic>> getStats() async {
    final boxes = [
      'products',
      'sales',
      'expenses',
      'inventory',
      'vendors',
      'stock_items',
      'dashboard_stats',
      'categories',
      'suppliers',
      'deliveries',
      'bookings',
      'purchase_orders',
    ];
    
    final stats = <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    
    for (final boxName in boxes) {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box(boxName);
        final lastSync = await getLastSync(boxName);
        
        stats[boxName] = {
          'count': box.length,
          'last_sync': lastSync?.toIso8601String(),
        };
      }
    }
    
    return stats;
  }
}

