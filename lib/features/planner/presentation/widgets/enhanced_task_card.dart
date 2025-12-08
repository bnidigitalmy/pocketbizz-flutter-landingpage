import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/planner_task.dart';

class EnhancedTaskCard extends StatelessWidget {
  final PlannerTask task;
  final VoidCallback onTap;
  final VoidCallback? onStatusChanged;

  const EnhancedTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.onStatusChanged,
  });

  Color _getStatusColor() {
    switch (task.status) {
      case 'done':
        return Colors.green.shade100;
      case 'in_progress':
        return Colors.blue.shade100;
      case 'snoozed':
        return Colors.orange.shade100;
      case 'cancelled':
        return Colors.grey.shade200;
      default:
        return task.isOverdue ? Colors.red.shade50 : Colors.white;
    }
  }

  Color _getPriorityColor() {
    switch (task.priority) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.blueGrey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _getStatusColor(),
      elevation: task.isOverdue ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Status icon
                  Icon(
                    task.status == 'done'
                        ? Icons.check_circle
                        : task.status == 'in_progress'
                            ? Icons.play_circle_outline
                            : task.isAuto
                                ? Icons.bolt
                                : Icons.radio_button_unchecked,
                    color: task.status == 'done'
                        ? Colors.green
                        : task.status == 'in_progress'
                            ? Colors.blue
                            : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  // Title
                  Expanded(
                    child: Text(
                      task.title.isNotEmpty ? task.title : 'Untitled Task',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: task.status == 'done'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Priority badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPriorityColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.priority.toUpperCase(),
                      style: TextStyle(
                        color: _getPriorityColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              // Description
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              // Subtasks progress
              if ((task.subtasks.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.checklist, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${task.completedSubtasksCount}/${task.totalSubtasksCount} subtasks',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: task.progressPercentage,
                        backgroundColor: Colors.grey.shade300,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Footer row
              Row(
                children: [
                  // Due date
                  if (task.dueAt != null) ...[
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('d MMM, h:mm a', 'ms_MY').format(task.dueAt!),
                      style: TextStyle(
                        fontSize: 12,
                        color: task.isOverdue ? Colors.red : Colors.grey.shade700,
                        fontWeight: task.isOverdue ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Tags
                  if ((task.tags.isNotEmpty)) ...[
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        children: [
                          ...task.tags.take(2).map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                          if (task.tags.length > 2)
                            Text(
                              '+${task.tags.length - 2}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // Auto badge
                  if (task.isAuto)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'AUTO',
                        style: TextStyle(
                          color: Colors.teal,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              // Time tracking
              if (task.estimatedHours != null || task.timeSpentMinutes > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        children: [
                          if (task.estimatedHours != null)
                            Text(
                              'Est: ${task.estimatedHours!.toStringAsFixed(1)}h',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          if (task.timeSpentMinutes > 0)
                            Text(
                              'Spent: ${(task.timeSpentMinutes / 60).toStringAsFixed(1)}h',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

