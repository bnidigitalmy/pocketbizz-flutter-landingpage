import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_helper.dart';
import '../../../../data/models/planner_task.dart';
import '../../../../data/models/planner_subtask.dart';
import '../../../../data/models/planner_comment.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../subscription/widgets/subscription_guard.dart';

class TaskDetailBottomSheet extends StatefulWidget {
  final PlannerTask task;
  final PlannerTasksRepositorySupabase repo;
  final VoidCallback onUpdated;

  const TaskDetailBottomSheet({
    super.key,
    required this.task,
    required this.repo,
    required this.onUpdated,
  });

  @override
  State<TaskDetailBottomSheet> createState() => _TaskDetailBottomSheetState();
}

class _TaskDetailBottomSheetState extends State<TaskDetailBottomSheet> {
  late PlannerTask _task;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _refreshTask();
  }

  Future<void> _refreshTask() async {
    final updated = await widget.repo.getTask(_task.id);
    if (updated != null && mounted) {
      setState(() => _task = updated);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    await requirePro(context, 'Kemaskini Status Tugasan', () async {
      setState(() => _loading = true);
      try {
        await widget.repo.updateTask(_task.id, {'status': newStatus});
        if (newStatus == 'done') {
          await widget.repo.updateTask(_task.id, {
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
        await _refreshTask();
        widget.onUpdated();
      } catch (e) {
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Kemaskini Status Tugasan',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  Future<void> _toggleSubtask(int index) async {
    final subtasks = List<PlannerSubtask>.from(_task.subtasks ?? []);
    subtasks[index] = PlannerSubtask(
      id: subtasks[index].id,
      title: subtasks[index].title,
      done: !subtasks[index].done,
      completedAt: !subtasks[index].done ? DateTime.now() : null,
    );
    await widget.repo.updateSubtasks(_task.id, subtasks);
    await _refreshTask();
    widget.onUpdated();
  }

  Future<void> _addSubtask(String title) async {
    await requirePro(context, 'Tambah Subtask', () async {
      final newSubtask = PlannerSubtask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        done: false,
      );
      final subtasks = <PlannerSubtask>[...(_task.subtasks ?? []), newSubtask];
      try {
        await widget.repo.updateSubtasks(_task.id, subtasks);
        await _refreshTask();
        widget.onUpdated();
      } catch (e) {
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah Subtask',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    });
  }

  Future<void> _addComment(String text) async {
    await requirePro(context, 'Tambah Komen', () async {
      try {
        await widget.repo.addComment(_task.id, text);
        await _refreshTask();
        widget.onUpdated();
      } catch (e) {
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah Komen',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    });
  }

  Future<void> _updateTimeSpent(int minutes) async {
    await widget.repo.addTimeSpent(_task.id, minutes);
    await _refreshTask();
    widget.onUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _task.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status & Priority
                Row(
                  children: [
                    Expanded(
                      child: _StatusChip(
                        status: _task.status,
                        onTap: () => _showStatusDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PriorityChip(priority: _task.priority),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                if (_task.description != null && _task.description!.isNotEmpty) ...[
                  Text(
                    'Penerangan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_task.description!),
                  const SizedBox(height: 16),
                ],
                // Due date
                if (_task.dueAt != null) ...[
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy, h:mm a', 'ms_MY').format(_task.dueAt!),
                        style: TextStyle(
                          color: _task.isOverdue ? Colors.red : Colors.grey.shade700,
                          fontWeight: _task.isOverdue ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Time tracking
                if (_task.estimatedHours != null || _task.timeSpentMinutes > 0) ...[
                  _TimeTrackingSection(
                    estimatedHours: _task.estimatedHours,
                    timeSpentMinutes: _task.timeSpentMinutes,
                    onAddTime: _updateTimeSpent,
                  ),
                  const SizedBox(height: 16),
                ],
                // Subtasks
                _SubtasksSection(
                  subtasks: _task.subtasks ?? [],
                  onToggle: _toggleSubtask,
                  onAdd: _addSubtask,
                ),
                const SizedBox(height: 16),
                // Comments
                _CommentsSection(
                  comments: _task.comments ?? [],
                  onAdd: _addComment,
                ),
              ],
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                if (_task.status != 'in_progress' && _task.status != 'done')
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mula'),
                      onPressed: () => _updateStatus('in_progress'),
                    ),
                  ),
                if (_task.status != 'done') ...[
                  if (_task.status != 'in_progress' && _task.status != 'done')
                    const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Selesai'),
                      onPressed: () => _updateStatus('done'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tukar Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Buka'),
              leading: const Icon(Icons.radio_button_unchecked),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              title: const Text('Sedang'),
              leading: const Icon(Icons.play_circle_outline),
              onTap: () => Navigator.pop(context, 'in_progress'),
            ),
            ListTile(
              title: const Text('Selesai'),
              leading: const Icon(Icons.check_circle),
              onTap: () => Navigator.pop(context, 'done'),
            ),
            ListTile(
              title: const Text('Tunda'),
              leading: const Icon(Icons.snooze),
              onTap: () => Navigator.pop(context, 'snoozed'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _updateStatus(result);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final VoidCallback onTap;

  const _StatusChip({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open' => ('Buka', Colors.blue),
      'in_progress' => ('Sedang', Colors.orange),
      'done' => ('Selesai', Colors.green),
      'snoozed' => ('Tunda', Colors.amber),
      _ => ('Buka', Colors.grey),
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;

  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      'critical' => ('KRITIKAL', Colors.red),
      'high' => ('TINGGI', Colors.orange),
      'low' => ('RENDAH', Colors.blueGrey),
      _ => ('NORMAL', Colors.blue),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _TimeTrackingSection extends StatelessWidget {
  final double? estimatedHours;
  final int timeSpentMinutes;
  final ValueChanged<int> onAddTime;

  const _TimeTrackingSection({
    this.estimatedHours,
    required this.timeSpentMinutes,
    required this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Masa',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (estimatedHours != null)
              Text('Anggaran: ${estimatedHours!.toStringAsFixed(1)} jam'),
            Text('Digunakan: ${(timeSpentMinutes / 60).toStringAsFixed(1)} jam'),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('+15 min'),
                  onPressed: () => onAddTime(15),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('+30 min'),
                  onPressed: () => onAddTime(30),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('+1 jam'),
                  onPressed: () => onAddTime(60),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtasksSection extends StatelessWidget {
  final List<PlannerSubtask> subtasks;
  final ValueChanged<int> onToggle;
  final ValueChanged<String> onAdd;

  const _SubtasksSection({
    required this.subtasks,
    required this.onToggle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Subtasks (${subtasks.where((s) => s.done).length}/${subtasks.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...subtasks.asMap().entries.map((entry) {
              final index = entry.key;
              final subtask = entry.value;
              return CheckboxListTile(
                title: Text(
                  subtask.title,
                  style: subtask.done
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                value: subtask.done,
                onChanged: (_) => onToggle(index),
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Tambah subtask'),
              onPressed: () async {
                final controller = TextEditingController();
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Tambah Subtask'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Nama subtask',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Tambah'),
                      ),
                    ],
                  ),
                );
                if (result == true && controller.text.trim().isNotEmpty) {
                  onAdd(controller.text.trim());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsSection extends StatefulWidget {
  final List<PlannerComment> comments;
  final ValueChanged<String> onAdd;

  const _CommentsSection({required this.comments, required this.onAdd});

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.comment, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Komen (${widget.comments.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...widget.comments.map((comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        child: Text(
                          comment.userId.length >= 2
                              ? comment.userId.substring(0, 2).toUpperCase()
                              : 'U',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.text,
                              style: const TextStyle(fontSize: 14),
                            ),
                            Text(
                              DateFormat('d MMM, h:mm a', 'ms_MY').format(DateTimeHelper.toLocalTime(comment.createdAt)),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Tambah komen...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_commentController.text.trim().isNotEmpty) {
                      widget.onAdd(_commentController.text.trim());
                      _commentController.clear();
                    }
                  },
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  widget.onAdd(text.trim());
                  _commentController.clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
