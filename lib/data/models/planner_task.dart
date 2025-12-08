import 'dart:convert';

import 'planner_subtask.dart';
import 'planner_comment.dart';

class PlannerTask {
  final String id;
  final String title;
  final String type; // manual | auto_*
  final String status; // open | in_progress | done | snoozed | dismissed | cancelled
  final String priority; // low | normal | high | critical
  final DateTime? dueAt;
  final DateTime? remindAt;
  final DateTime? snoozeUntil;
  final String? linkedType;
  final String? linkedId;
  final String? source;
  final Map<String, dynamic>? metadata;
  final bool isAuto;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields
  final String? description;
  final String? notes;
  final List<PlannerSubtask> subtasks;
  final bool isRecurring;
  final String? recurrencePattern; // daily, weekly, monthly, yearly, custom
  final int? recurrenceInterval;
  final List<int>? recurrenceDays; // for weekly: [1,3,5] = Mon,Wed,Fri
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final DateTime? nextOccurrenceAt;
  final String? parentTaskId;
  final String? categoryId;
  final String? projectId;
  final List<String> tags;
  final List<String> dependsOnTaskIds;
  final List<String> blocksTaskIds;
  final double? estimatedHours;
  final double? actualHours;
  final int timeSpentMinutes;
  final DateTime? startedAt;
  final List<String> attachmentUrls;
  final List<PlannerComment> comments;
  final String? templateId;
  final bool isTemplate;
  final List<String> sharedWithUserIds;
  final String? location;
  final DateTime? reminderSentAt;

  PlannerTask({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.priority,
    required this.dueAt,
    required this.remindAt,
    required this.snoozeUntil,
    required this.linkedType,
    required this.linkedId,
    required this.source,
    required this.metadata,
    required this.isAuto,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.notes,
    List<PlannerSubtask>? subtasks,
    this.isRecurring = false,
    this.recurrencePattern,
    this.recurrenceInterval,
    this.recurrenceDays,
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.nextOccurrenceAt,
    this.parentTaskId,
    this.categoryId,
    this.projectId,
    List<String>? tags,
    List<String>? dependsOnTaskIds,
    List<String>? blocksTaskIds,
    this.estimatedHours,
    this.actualHours,
    this.timeSpentMinutes = 0,
    this.startedAt,
    List<String>? attachmentUrls,
    List<PlannerComment>? comments,
    this.templateId,
    this.isTemplate = false,
    List<String>? sharedWithUserIds,
    this.location,
    this.reminderSentAt,
  })  : subtasks = subtasks ?? [],
        tags = tags ?? [],
        dependsOnTaskIds = dependsOnTaskIds ?? [],
        blocksTaskIds = blocksTaskIds ?? [],
        attachmentUrls = attachmentUrls ?? [],
        comments = comments ?? [],
        sharedWithUserIds = sharedWithUserIds ?? [];

  bool get isOverdue =>
      status != 'done' && status != 'cancelled' && dueAt != null && dueAt!.isBefore(DateTime.now());

  bool get isInProgress => status == 'in_progress';

  int get completedSubtasksCount {
    final subs = subtasks;
    if (subs.isEmpty) return 0;
    return subs.where((s) => s.done).length;
  }
  
  int get totalSubtasksCount => subtasks.length;
  
  bool get allSubtasksDone {
    final subs = subtasks;
    return subs.isNotEmpty && subs.every((s) => s.done);
  }

  double get progressPercentage {
    final total = totalSubtasksCount;
    if (total == 0) return status == 'done' ? 1.0 : 0.0;
    return completedSubtasksCount / total;
  }

  factory PlannerTask.fromJson(Map<String, dynamic> json) {
    DateTime? _parseTs(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    List<PlannerSubtask> _parseSubtasks(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => PlannerSubtask.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => PlannerSubtask.fromJson(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    List<PlannerComment> _parseComments(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => PlannerComment.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (value is String) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((e) => PlannerComment.fromJson(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    List<String> _parseStringArray(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<int>? _parseIntArray(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value.map((e) => int.tryParse(e.toString()) ?? 0).toList();
      }
      return null;
    }

    return PlannerTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'manual',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      dueAt: _parseTs(json['due_at']),
      remindAt: _parseTs(json['remind_at']),
      snoozeUntil: _parseTs(json['snooze_until']),
      linkedType: json['linked_type'] as String?,
      linkedId: json['linked_id'] as String?,
      source: json['source'] as String?,
      metadata: _parseMetadata(json['metadata']),
      isAuto: json['is_auto'] as bool? ?? false,
      completedAt: _parseTs(json['completed_at']),
      createdAt: _parseTs(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseTs(json['updated_at']) ?? DateTime.now(),
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      subtasks: _parseSubtasks(json['subtasks']),
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrencePattern: json['recurrence_pattern'] as String?,
      recurrenceInterval: json['recurrence_interval'] as int?,
      recurrenceDays: _parseIntArray(json['recurrence_days']),
      recurrenceEndDate: json['recurrence_end_date'] != null
          ? DateTime.tryParse(json['recurrence_end_date'].toString())
          : null,
      recurrenceCount: json['recurrence_count'] as int?,
      nextOccurrenceAt: _parseTs(json['next_occurrence_at']),
      parentTaskId: json['parent_task_id'] as String?,
      categoryId: json['category_id'] as String?,
      projectId: json['project_id'] as String?,
      tags: _parseStringArray(json['tags']),
      dependsOnTaskIds: _parseStringArray(json['depends_on_task_ids']),
      blocksTaskIds: _parseStringArray(json['blocks_task_ids']),
      estimatedHours: json['estimated_hours'] != null
          ? (json['estimated_hours'] as num).toDouble()
          : null,
      actualHours: json['actual_hours'] != null ? (json['actual_hours'] as num).toDouble() : null,
      timeSpentMinutes: json['time_spent_minutes'] as int? ?? 0,
      startedAt: _parseTs(json['started_at']),
      attachmentUrls: _parseStringArray(json['attachment_urls']),
      comments: _parseComments(json['comments']),
      templateId: json['template_id'] as String?,
      isTemplate: json['is_template'] as bool? ?? false,
      sharedWithUserIds: _parseStringArray(json['shared_with_user_ids']),
      location: json['location'] as String?,
      reminderSentAt: _parseTs(json['reminder_sent_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'status': status,
        'priority': priority,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'remind_at': remindAt?.toUtc().toIso8601String(),
        'snooze_until': snoozeUntil?.toUtc().toIso8601String(),
        'linked_type': linkedType,
        'linked_id': linkedId,
        'source': source,
        'metadata': metadata,
        'is_auto': isAuto,
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'description': description,
        'notes': notes,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'is_recurring': isRecurring,
        'recurrence_pattern': recurrencePattern,
        'recurrence_interval': recurrenceInterval,
        'recurrence_days': recurrenceDays,
        'recurrence_end_date': recurrenceEndDate?.toIso8601String().split('T')[0],
        'recurrence_count': recurrenceCount,
        'next_occurrence_at': nextOccurrenceAt?.toUtc().toIso8601String(),
        'parent_task_id': parentTaskId,
        'category_id': categoryId,
        'project_id': projectId,
        'tags': tags,
        'depends_on_task_ids': dependsOnTaskIds,
        'blocks_task_ids': blocksTaskIds,
        'estimated_hours': estimatedHours,
        'actual_hours': actualHours,
        'time_spent_minutes': timeSpentMinutes,
        'started_at': startedAt?.toUtc().toIso8601String(),
        'attachment_urls': attachmentUrls,
        'comments': comments.map((c) => c.toJson()).toList(),
        'template_id': templateId,
        'is_template': isTemplate,
        'shared_with_user_ids': sharedWithUserIds,
        'location': location,
        'reminder_sent_at': reminderSentAt?.toUtc().toIso8601String(),
      };

  static Map<String, dynamic>? _parseMetadata(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  PlannerTask copyWith({
    String? id,
    String? title,
    String? type,
    String? status,
    String? priority,
    DateTime? dueAt,
    DateTime? remindAt,
    DateTime? snoozeUntil,
    String? linkedType,
    String? linkedId,
    String? source,
    Map<String, dynamic>? metadata,
    bool? isAuto,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    String? notes,
    List<PlannerSubtask>? subtasks,
    bool? isRecurring,
    String? recurrencePattern,
    int? recurrenceInterval,
    List<int>? recurrenceDays,
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    DateTime? nextOccurrenceAt,
    String? parentTaskId,
    String? categoryId,
    String? projectId,
    List<String>? tags,
    List<String>? dependsOnTaskIds,
    List<String>? blocksTaskIds,
    double? estimatedHours,
    double? actualHours,
    int? timeSpentMinutes,
    DateTime? startedAt,
    List<String>? attachmentUrls,
    List<PlannerComment>? comments,
    String? templateId,
    bool? isTemplate,
    List<String>? sharedWithUserIds,
    String? location,
    DateTime? reminderSentAt,
  }) {
    return PlannerTask(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      remindAt: remindAt ?? this.remindAt,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      linkedType: linkedType ?? this.linkedType,
      linkedId: linkedId ?? this.linkedId,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
      isAuto: isAuto ?? this.isAuto,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      subtasks: subtasks ?? this.subtasks,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      nextOccurrenceAt: nextOccurrenceAt ?? this.nextOccurrenceAt,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      categoryId: categoryId ?? this.categoryId,
      projectId: projectId ?? this.projectId,
      tags: tags ?? this.tags,
      dependsOnTaskIds: dependsOnTaskIds ?? this.dependsOnTaskIds,
      blocksTaskIds: blocksTaskIds ?? this.blocksTaskIds,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      timeSpentMinutes: timeSpentMinutes ?? this.timeSpentMinutes,
      startedAt: startedAt ?? this.startedAt,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      comments: comments ?? this.comments,
      templateId: templateId ?? this.templateId,
      isTemplate: isTemplate ?? this.isTemplate,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
      location: location ?? this.location,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
    );
  }
}
