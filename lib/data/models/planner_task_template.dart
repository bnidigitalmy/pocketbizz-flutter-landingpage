import 'dart:convert';
import 'planner_task.dart';
import 'planner_subtask.dart';

class PlannerTaskTemplate {
  final String id;
  final String name;
  final String title;
  final String? description;
  final String? categoryId;
  final String? projectId;
  final String priority;
  final double? estimatedHours;
  final List<PlannerSubtask> subtasks;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlannerTaskTemplate({
    required this.id,
    required this.name,
    required this.title,
    this.description,
    this.categoryId,
    this.projectId,
    this.priority = 'normal',
    this.estimatedHours,
    List<PlannerSubtask>? subtasks,
    List<String>? tags,
    required this.createdAt,
    required this.updatedAt,
  })  : subtasks = subtasks ?? [],
        tags = tags ?? [];

  factory PlannerTaskTemplate.fromJson(Map<String, dynamic> json) {
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

    List<String> _parseStringArray(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }

    return PlannerTaskTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      projectId: json['project_id'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      estimatedHours: json['estimated_hours'] != null
          ? (json['estimated_hours'] as num).toDouble()
          : null,
      subtasks: _parseSubtasks(json['subtasks']),
      tags: _parseStringArray(json['tags']),
      createdAt: _parseTs(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseTs(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'description': description,
        'category_id': categoryId,
        'project_id': projectId,
        'priority': priority,
        'estimated_hours': estimatedHours,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'tags': tags,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

