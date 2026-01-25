import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service untuk track cache keys yang pernah digunakan
/// Supaya kita boleh invalidate semua cache keys yang related, termasuk yang baru
class CacheKeyTracker {
  static const String _prefix = 'cache_keys_';
  
  /// Register cache key yang digunakan
  /// Call ini setiap kali kita create/open cache box
  static Future<void> registerKey(String prefix, String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackerKey = '$_prefix$prefix';
      final existingKeys = prefs.getStringList(trackerKey) ?? [];
      
      if (!existingKeys.contains(key)) {
        existingKeys.add(key);
        await prefs.setStringList(trackerKey, existingKeys);
        debugPrint('📝 Registered cache key: $key (prefix: $prefix)');
      }
    } catch (e) {
      debugPrint('⚠️ Error registering cache key: $e');
    }
  }
  
  /// Get semua cache keys untuk prefix tertentu
  /// Contoh: getKeys('categories') akan return semua keys yang start dengan 'categories'
  static Future<List<String>> getKeys(String prefix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackerKey = '$_prefix$prefix';
      return prefs.getStringList(trackerKey) ?? [];
    } catch (e) {
      debugPrint('⚠️ Error getting cache keys: $e');
      return [];
    }
  }
  
  /// Clear semua tracked keys untuk prefix tertentu
  static Future<void> clearKeys(String prefix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackerKey = '$_prefix$prefix';
      await prefs.remove(trackerKey);
      debugPrint('🗑️ Cleared tracked keys for prefix: $prefix');
    } catch (e) {
      debugPrint('⚠️ Error clearing tracked keys: $e');
    }
  }
  
  /// Remove specific key dari tracker
  static Future<void> removeKey(String prefix, String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackerKey = '$_prefix$prefix';
      final existingKeys = prefs.getStringList(trackerKey) ?? [];
      existingKeys.remove(key);
      await prefs.setStringList(trackerKey, existingKeys);
    } catch (e) {
      debugPrint('⚠️ Error removing cache key: $e');
    }
  }
}

