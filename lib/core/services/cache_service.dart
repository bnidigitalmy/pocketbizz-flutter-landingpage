import 'dart:async';
import 'package:flutter/foundation.dart';

/// Smart cache service with TTL (Time-To-Live) support
/// Works seamlessly with real-time subscriptions for auto-invalidation
class CacheService {
  static final Map<String, _CachedData> _cache = {};
  static final Map<String, List<VoidCallback>> _invalidationListeners = {};

  /// Get data from cache or fetch if expired/missing
  /// 
  /// Example:
  /// ```dart
  /// final stats = await CacheService.getOrFetch(
  ///   'dashboard_stats',
  ///   () => _bookingsRepo.getStatistics(),
  ///   ttl: Duration(minutes: 5),
  /// );
  /// ```
  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    // Check if cache exists and is still valid
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      debugPrint('✅ Cache hit: $key');
      return cached.data as T;
    }

    // Cache miss or expired - fetch new data
    debugPrint('🔄 Cache miss: $key - fetching new data...');
    final data = await fetcher();
    
    // Store in cache with expiration time
    _cache[key] = _CachedData(
      data: data,
      expiresAt: DateTime.now().add(ttl),
    );
    
    return data;
  }

  /// Invalidate specific cache key
  /// Called automatically by real-time subscriptions when data changes
  /// 
  /// Example:
  /// ```dart
  /// // Real-time detects change
  /// CacheService.invalidate('dashboard_stats');
  /// ```
  static void invalidate(String key) {
    _cache.remove(key);
    debugPrint('🗑️ Cache invalidated: $key');
    
    // Notify listeners
    final listeners = _invalidationListeners[key];
    if (listeners != null) {
      for (final listener in listeners) {
        listener();
      }
    }
  }

  /// Invalidate multiple cache keys at once
  /// Useful when related data changes
  static void invalidateMultiple(List<String> keys) {
    for (final key in keys) {
      invalidate(key);
    }
  }

  /// Clear all cache
  static void clearAll() {
    _cache.clear();
    _invalidationListeners.clear();
    debugPrint('🗑️ All cache cleared');
  }

  /// Register a listener to be called when cache is invalidated
  /// Useful for triggering UI updates
  static void onInvalidate(String key, VoidCallback listener) {
    _invalidationListeners.putIfAbsent(key, () => []).add(listener);
  }

  /// Remove invalidation listener
  static void removeInvalidationListener(String key, VoidCallback listener) {
    _invalidationListeners[key]?.remove(listener);
  }

  /// Check if cache exists and is valid
  static bool hasValidCache(String key) {
    final cached = _cache[key];
    return cached != null && !cached.isExpired;
  }

  /// Get cache expiration time
  static DateTime? getExpirationTime(String key) {
    return _cache[key]?.expiresAt;
  }

  /// Get cache statistics (for debugging)
  static Map<String, dynamic> getStats() {
    final valid = _cache.values.where((c) => !c.isExpired).length;
    final expired = _cache.values.where((c) => c.isExpired).length;
    
    return {
      'total': _cache.length,
      'valid': valid,
      'expired': expired,
      'keys': _cache.keys.toList(),
    };
  }
}

/// Internal class to store cached data with expiration
class _CachedData {
  final dynamic data;
  final DateTime expiresAt;

  _CachedData({
    required this.data,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

