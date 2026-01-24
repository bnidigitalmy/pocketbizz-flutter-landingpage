import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../models/planner_task.dart';
import 'planner_tasks_repository_supabase.dart';

/// Cached version of PlannerTasksRepository dengan Stale-While-Revalidate
///
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Scope-aware caching (today, upcoming, overdue, auto)
/// - Offline-first approach
///
/// Priority: MEDIUM (Used for daily task management)
class PlannerTasksRepositorySupabaseCached {
  final PlannerTasksRepositorySupabase _baseRepo =
      PlannerTasksRepositorySupabase();

  static const String _boxName = 'planner_tasks';
  static const String _lastSyncPrefix = 'planner_last_sync_';
  static bool _initialized = false;

  /// Initialize Hive box for planner cache
  static Future<void> initialize() async {
    if (_initialized) return;

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    _initialized = true;
    debugPrint('✅ PlannerTasksRepositorySupabaseCached initialized');
  }

  /// List tasks dengan persistent cache + Stale-While-Revalidate
  ///
  /// Returns cached data immediately, syncs in background
  Future<List<PlannerTask>> listTasksCached({
    String scope = 'today',
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<PlannerTask>)? onDataUpdated,
  }) async {
    await initialize();

    final box = Hive.box(_boxName);
    final cacheKey = 'tasks_$scope';

    // 1. STALE: Return cached data immediately
    if (!forceRefresh && box.containsKey(cacheKey)) {
      try {
        final cachedJson = box.get(cacheKey) as String;
        final cachedList = (jsonDecode(cachedJson) as List)
            .map((json) => PlannerTask.fromJson(json as Map<String, dynamic>))
            .toList();
        debugPrint('✅ Cache hit (stale): $cacheKey - ${cachedList.length} tasks');

        // 2. REVALIDATE: Background sync
        _syncTasksInBackground(
          scope: scope,
          limit: limit,
          offset: offset,
          cacheKey: cacheKey,
          onDataUpdated: onDataUpdated,
        );

        return cachedList;
      } catch (e) {
        debugPrint('⚠️ Error loading planner cache: $e');
      }
    }

    // 3. CACHE MISS: Fetch fresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh tasks...');
    try {
      final tasks = await _baseRepo.listTasks(
        scope: scope,
        limit: limit,
        offset: offset,
      );

      // Store in cache
      await box.put(cacheKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('✅ Fresh tasks cached: $cacheKey - ${tasks.length} tasks');
      return tasks;
    } catch (e) {
      debugPrint('❌ Error fetching tasks: $e');
      rethrow;
    }
  }

  /// Background sync for tasks
  Future<void> _syncTasksInBackground({
    required String scope,
    int limit = 50,
    int offset = 0,
    required String cacheKey,
    void Function(List<PlannerTask>)? onDataUpdated,
  }) async {
    try {
      final tasks = await _baseRepo.listTasks(
        scope: scope,
        limit: limit,
        offset: offset,
      );

      final box = Hive.box(_boxName);
      await box.put(cacheKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('🔄 Background sync completed: $cacheKey');

      if (onDataUpdated != null) {
        onDataUpdated(tasks);
      }
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }

  /// Update last sync timestamp
  Future<void> _updateLastSync(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_lastSyncPrefix$cacheKey', DateTime.now().toIso8601String());
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSync(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('$_lastSyncPrefix$cacheKey');
    if (lastSyncStr == null) return null;
    return DateTime.tryParse(lastSyncStr);
  }

  /// Force refresh tasks for specific scope
  Future<List<PlannerTask>> refreshTasks({
    String scope = 'today',
    int limit = 50,
    int offset = 0,
  }) async {
    return await listTasksCached(
      scope: scope,
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }

  /// Sync tasks in background (non-blocking)
  Future<void> syncInBackground({
    String scope = 'today',
    int limit = 50,
    int offset = 0,
    void Function(List<PlannerTask>)? onDataUpdated,
  }) async {
    try {
      await listTasksCached(
        scope: scope,
        limit: limit,
        offset: offset,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: planner_tasks ($scope)');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }

  /// Invalidate all planner cache
  Future<void> invalidateCache() async {
    await initialize();
    final box = Hive.box(_boxName);
    await box.clear();
    debugPrint('🗑️ Planner cache invalidated');
  }

  /// Invalidate cache for specific scope
  Future<void> invalidateScopeCache(String scope) async {
    await initialize();
    final box = Hive.box(_boxName);
    final cacheKey = 'tasks_$scope';
    await box.delete(cacheKey);
    debugPrint('🗑️ Planner cache invalidated for scope: $scope');
  }

  // ============================================================================
  // Delegate methods to base repo (these modify data, so invalidate cache)
  // ============================================================================

  Future<PlannerTask?> createTask({
    required String title,
    String? description,
    String? notes,
    DateTime? dueAt,
    DateTime? remindAt,
    String priority = 'normal',
    String? categoryId,
    String? projectId,
    List<String>? tags,
  }) async {
    final result = await _baseRepo.createTask(
      title: title,
      description: description,
      notes: notes,
      dueAt: dueAt,
      remindAt: remindAt,
      priority: priority,
      categoryId: categoryId,
      projectId: projectId,
      tags: tags,
    );
    await invalidateCache(); // Invalidate all scopes after create
    return result;
  }

  Future<PlannerTask?> updateTask(
      String taskId, Map<String, dynamic> updates) async {
    final result = await _baseRepo.updateTask(taskId, updates);
    await invalidateCache();
    return result;
  }

  Future<void> markDone(String taskId) async {
    await _baseRepo.markDone(taskId);
    await invalidateCache();
  }

  Future<void> startTask(String taskId) async {
    await _baseRepo.startTask(taskId);
    await invalidateCache();
  }

  Future<void> snooze(String taskId, Duration duration) async {
    await _baseRepo.snooze(taskId, duration);
    await invalidateCache();
  }

  Future<void> deleteTask(String taskId) async {
    await _baseRepo.deleteTask(taskId);
    await invalidateCache();
  }

  // Delegate read-only methods directly
  Future<PlannerTask?> getTask(String taskId) async {
    return await _baseRepo.getTask(taskId);
  }

  Future<Map<String, dynamic>> getTaskStats() async {
    return await _baseRepo.getTaskStats();
  }
}
