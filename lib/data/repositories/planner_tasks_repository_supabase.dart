import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client.dart';
import '../models/planner_task.dart';
import '../models/planner_subtask.dart';
import '../models/planner_comment.dart';
import '../models/planner_category.dart';
import '../models/planner_project.dart';
import '../models/planner_task_template.dart';

class PlannerTasksRepositorySupabase {
  static const _table = 'planner_tasks';
  static const _categoriesTable = 'planner_categories';
  static const _projectsTable = 'planner_projects';
  static const _templatesTable = 'planner_task_templates';

  // ============================================================================
  // TASK CRUD
  // ============================================================================

  Future<List<PlannerTask>> listTasks({
    String scope = 'today',
    int limit = 50,
    int offset = 0,
    String? categoryId,
    String? projectId,
    String? status,
    String? priority,
    List<String>? tags,
    String? searchQuery,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final endToday = startToday.add(const Duration(days: 1));

    var query = supabase
        .from(_table)
        .select()
        .eq('business_owner_id', userId);

    // Scope filters
    if (scope == 'today') {
      query = query
          .gte('due_at', startToday.toUtc().toIso8601String())
          .lt('due_at', endToday.toUtc().toIso8601String());
    } else if (scope == 'overdue') {
      query = query
          .lt('due_at', startToday.toUtc().toIso8601String())
          .neq('status', 'done')
          .neq('status', 'cancelled');
    } else if (scope == 'upcoming') {
      query = query.gte('due_at', endToday.toUtc().toIso8601String());
    } else if (scope == 'auto') {
      query = query.eq('is_auto', true);
    } else if (scope == 'in_progress') {
      query = query.eq('status', 'in_progress');
    }

    // Additional filters
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (projectId != null) {
      query = query.eq('project_id', projectId);
    }
    if (status != null) {
      query = query.eq('status', status);
    }
    if (priority != null) {
      query = query.eq('priority', priority);
    }
    if (tags != null && tags.isNotEmpty) {
      query = query.contains('tags', tags);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
    }

    final resp = await query
        .order('due_at', ascending: true)
        .range(offset, offset + limit - 1);
    final List data = resp as List? ?? [];
    return data.map((e) => PlannerTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlannerTask?> getTask(String taskId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final resp = await supabase
        .from(_table)
        .select()
        .eq('id', taskId)
        .eq('business_owner_id', userId)
        .maybeSingle();

    if (resp == null) return null;
    return PlannerTask.fromJson(resp as Map<String, dynamic>);
  }

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
    double? estimatedHours,
    List<PlannerSubtask>? subtasks,
    bool isRecurring = false,
    String? recurrencePattern,
    int? recurrenceInterval,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    String? location,
    String? templateId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final insert = {
      'title': title,
      'description': description,
      'notes': notes,
      'type': 'manual',
      'status': 'open',
      'priority': priority,
      'due_at': dueAt?.toUtc().toIso8601String(),
      'remind_at': remindAt?.toUtc().toIso8601String(),
      'category_id': categoryId,
      'project_id': projectId,
      'tags': tags ?? [],
      'estimated_hours': estimatedHours,
      'subtasks': subtasks?.map((s) => s.toJson()).toList() ?? [],
      'is_recurring': isRecurring,
      'recurrence_pattern': recurrencePattern,
      'recurrence_interval': recurrenceInterval,
      'recurrence_days': recurrenceDays,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String().split('T')[0],
      'recurrence_count': recurrenceCount,
      'location': location,
      'template_id': templateId,
      'business_owner_id': userId,
      'is_auto': false,
    };

    final resp = await supabase.from(_table).insert(insert).select().single();
    return PlannerTask.fromJson(resp as Map<String, dynamic>);
  }

  Future<PlannerTask?> updateTask(String taskId, Map<String, dynamic> updates) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    // Convert subtasks if present
    if (updates.containsKey('subtasks') && updates['subtasks'] is List<PlannerSubtask>) {
      updates['subtasks'] = (updates['subtasks'] as List<PlannerSubtask>)
          .map((s) => s.toJson())
          .toList();
    }

    // Convert comments if present
    if (updates.containsKey('comments') && updates['comments'] is List<PlannerComment>) {
      updates['comments'] = (updates['comments'] as List<PlannerComment>)
          .map((c) => c.toJson())
          .toList();
    }

    // Convert dates
    if (updates.containsKey('due_at') && updates['due_at'] is DateTime) {
      updates['due_at'] = (updates['due_at'] as DateTime).toUtc().toIso8601String();
    }
    if (updates.containsKey('remind_at') && updates['remind_at'] is DateTime) {
      updates['remind_at'] = (updates['remind_at'] as DateTime).toUtc().toIso8601String();
    }
    if (updates.containsKey('recurrence_end_date') && updates['recurrence_end_date'] is DateTime) {
      updates['recurrence_end_date'] =
          (updates['recurrence_end_date'] as DateTime).toIso8601String().split('T')[0];
    }

    final resp = await supabase
        .from(_table)
        .update(updates)
        .eq('id', taskId)
        .eq('business_owner_id', userId)
        .select()
        .single();

    return PlannerTask.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> markDone(String taskId) async {
    await updateTask(taskId, {
      'status': 'done',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> startTask(String taskId) async {
    await updateTask(taskId, {
      'status': 'in_progress',
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> snooze(String taskId, Duration duration) async {
    final newRemind = DateTime.now().add(duration);
    await updateTask(taskId, {
      'status': 'snoozed',
      'remind_at': newRemind.toUtc().toIso8601String(),
      'snooze_until': newRemind.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteTask(String taskId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from(_table).delete().eq('id', taskId).eq('business_owner_id', userId);
  }

  // ============================================================================
  // SUBTASKS
  // ============================================================================

  Future<PlannerTask?> updateSubtasks(String taskId, List<PlannerSubtask> subtasks) async {
    return await updateTask(taskId, {
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
    });
  }

  // ============================================================================
  // COMMENTS
  // ============================================================================

  Future<PlannerTask?> addComment(String taskId, String text) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final task = await getTask(taskId);
    if (task == null) return null;

    final newComment = PlannerComment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      text: text,
      createdAt: DateTime.now(),
    );

    final updatedComments = [...task.comments, newComment];
    return await updateTask(taskId, {
      'comments': updatedComments.map((c) => c.toJson()).toList(),
    });
  }

  // ============================================================================
  // TIME TRACKING
  // ============================================================================

  Future<PlannerTask?> updateTimeSpent(String taskId, int minutes) async {
    return await updateTask(taskId, {
      'time_spent_minutes': minutes,
      'actual_hours': minutes / 60.0,
    });
  }

  Future<PlannerTask?> addTimeSpent(String taskId, int minutes) async {
    final task = await getTask(taskId);
    if (task == null) return null;

    final newTotal = task.timeSpentMinutes + minutes;
    return await updateTimeSpent(taskId, newTotal);
  }

  // ============================================================================
  // AUTO TASKS (existing method with enhancements)
  // ============================================================================

  Future<PlannerTask?> upsertAutoTask({
    required String autoHash,
    required String title,
    required String type,
    required String source,
    String? linkedType,
    String? linkedId,
    DateTime? dueAt,
    DateTime? remindAt,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final payload = {
      'auto_hash': autoHash,
      'title': title,
      'type': type,
      'source': source,
      'linked_type': linkedType,
      'linked_id': linkedId,
      'due_at': dueAt?.toUtc().toIso8601String(),
      'remind_at': remindAt?.toUtc().toIso8601String(),
      'metadata': metadata,
      'business_owner_id': userId,
      'is_auto': true,
      'status': 'open',
    };

    try {
      final resp = await supabase
          .from(_table)
          .upsert(payload, onConflict: 'business_owner_id,auto_hash')
          .select()
          .single();
      return PlannerTask.fromJson(resp as Map<String, dynamic>);
    } catch (e) {
      final existing = await supabase
          .from(_table)
          .select()
          .eq('business_owner_id', userId)
          .eq('auto_hash', autoHash)
          .maybeSingle();

      if (existing != null) {
        final updated = await supabase
            .from(_table)
            .update(payload)
            .eq('id', existing['id'] as String)
            .select()
            .single();
        return PlannerTask.fromJson(updated as Map<String, dynamic>);
      } else {
        final inserted = await supabase
            .from(_table)
            .insert(payload)
            .select()
            .single();
        return PlannerTask.fromJson(inserted as Map<String, dynamic>);
      }
    }
  }

  // ============================================================================
  // CATEGORIES
  // ============================================================================

  Future<List<PlannerCategory>> listCategories() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final resp = await supabase
        .from(_categoriesTable)
        .select()
        .eq('business_owner_id', userId)
        .order('name');

    final List data = resp as List? ?? [];
    return data.map((e) => PlannerCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlannerCategory?> createCategory({
    required String name,
    String? color,
    String? icon,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final insert = {
      'name': name,
      'color': color,
      'icon': icon,
      'business_owner_id': userId,
    };

    final resp = await supabase.from(_categoriesTable).insert(insert).select().single();
    return PlannerCategory.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String categoryId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from(_categoriesTable)
        .delete()
        .eq('id', categoryId)
        .eq('business_owner_id', userId);
  }

  // ============================================================================
  // PROJECTS
  // ============================================================================

  Future<List<PlannerProject>> listProjects({bool includeArchived = false}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    var query = supabase
        .from(_projectsTable)
        .select()
        .eq('business_owner_id', userId);

    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }

    final resp = await query.order('name');
    final List data = resp as List? ?? [];
    return data.map((e) => PlannerProject.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlannerProject?> createProject({
    required String name,
    String? description,
    String? color,
    String? icon,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final insert = {
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'business_owner_id': userId,
    };

    final resp = await supabase.from(_projectsTable).insert(insert).select().single();
    return PlannerProject.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> archiveProject(String projectId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from(_projectsTable)
        .update({'is_archived': true})
        .eq('id', projectId)
        .eq('business_owner_id', userId);
  }

  Future<void> deleteProject(String projectId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from(_projectsTable)
        .delete()
        .eq('id', projectId)
        .eq('business_owner_id', userId);
  }

  // ============================================================================
  // TEMPLATES
  // ============================================================================

  Future<List<PlannerTaskTemplate>> listTemplates() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final resp = await supabase
        .from(_templatesTable)
        .select()
        .eq('business_owner_id', userId)
        .order('name');

    final List data = resp as List? ?? [];
    return data
        .map((e) => PlannerTaskTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PlannerTaskTemplate?> createTemplate({
    required String name,
    required String title,
    String? description,
    String? categoryId,
    String? projectId,
    String priority = 'normal',
    double? estimatedHours,
    List<PlannerSubtask>? subtasks,
    List<String>? tags,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final insert = {
      'name': name,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'project_id': projectId,
      'priority': priority,
      'estimated_hours': estimatedHours,
      'subtasks': subtasks?.map((s) => s.toJson()).toList() ?? [],
      'tags': tags ?? [],
      'business_owner_id': userId,
    };

    final resp = await supabase.from(_templatesTable).insert(insert).select().single();
    return PlannerTaskTemplate.fromJson(resp as Map<String, dynamic>);
  }

  Future<PlannerTask?> createTaskFromTemplate(String templateId, DateTime? dueAt) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final templateResp = await supabase
        .from(_templatesTable)
        .select()
        .eq('id', templateId)
        .eq('business_owner_id', userId)
        .maybeSingle();

    if (templateResp == null) return null;

    final template = PlannerTaskTemplate.fromJson(templateResp as Map<String, dynamic>);

    return await createTask(
      title: template.title,
      description: template.description,
      priority: template.priority,
      categoryId: template.categoryId,
      projectId: template.projectId,
      tags: template.tags,
      estimatedHours: template.estimatedHours,
      subtasks: template.subtasks,
      dueAt: dueAt,
      templateId: templateId,
    );
  }

  Future<void> deleteTemplate(String templateId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from(_templatesTable)
        .delete()
        .eq('id', templateId)
        .eq('business_owner_id', userId);
  }

  // ============================================================================
  // SEARCH & STATS
  // ============================================================================

  Future<List<PlannerTask>> searchTasks(String query) async {
    return await listTasks(
      scope: 'all',
      searchQuery: query,
      limit: 100,
    );
  }

  Future<Map<String, dynamic>> getTaskStats() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);

    final allTasks = await supabase
        .from(_table)
        .select('status, due_at, priority')
        .eq('business_owner_id', userId);

    final tasks = (allTasks as List).map((e) => e as Map<String, dynamic>).toList();

    int total = tasks.length;
    int done = tasks.where((t) => t['status'] == 'done').length;
    int inProgress = tasks.where((t) => t['status'] == 'in_progress').length;
    int overdue = tasks.where((t) {
      final due = t['due_at'];
      if (due == null) return false;
      final dueDate = DateTime.tryParse(due.toString());
      return dueDate != null &&
          dueDate.isBefore(startToday) &&
          t['status'] != 'done' &&
          t['status'] != 'cancelled';
    }).length;

    return {
      'total': total,
      'done': done,
      'in_progress': inProgress,
      'overdue': overdue,
      'open': total - done - inProgress - overdue,
    };
  }
}
