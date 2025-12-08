import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/planner_task.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';

class PlannerKanbanView extends StatefulWidget {
  final PlannerTasksRepositorySupabase repo;
  final String? categoryId;
  final String? projectId;
  final ValueChanged<PlannerTask> onTaskTap;

  const PlannerKanbanView({
    super.key,
    required this.repo,
    this.categoryId,
    this.projectId,
    required this.onTaskTap,
  });

  @override
  State<PlannerKanbanView> createState() => _PlannerKanbanViewState();
}

class _PlannerKanbanViewState extends State<PlannerKanbanView> {
  Map<String, List<PlannerTask>> _tasksByStatus = {
    'open': [],
    'in_progress': [],
    'done': [],
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      // Load tasks from different scopes
      final results = await Future.wait([
        widget.repo.listTasks(scope: 'today', categoryId: widget.categoryId, projectId: widget.projectId, limit: 200),
        widget.repo.listTasks(scope: 'upcoming', categoryId: widget.categoryId, projectId: widget.projectId, limit: 200),
        widget.repo.listTasks(scope: 'overdue', categoryId: widget.categoryId, projectId: widget.projectId, limit: 200),
        widget.repo.listTasks(scope: 'in_progress', categoryId: widget.categoryId, projectId: widget.projectId, limit: 200),
      ]);
      
      final allTasks = [...results[0], ...results[1], ...results[2], ...results[3]];

      final grouped = <String, List<PlannerTask>>{
        'open': [],
        'in_progress': [],
        'done': [],
      };

      for (final task in allTasks) {
        if (task.status == 'open' || task.status == 'snoozed') {
          grouped['open']!.add(task);
        } else if (task.status == 'in_progress') {
          grouped['in_progress']!.add(task);
        } else if (task.status == 'done') {
          grouped['done']!.add(task);
        }
      }

      if (mounted) {
        setState(() {
          _tasksByStatus = grouped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateTaskStatus(PlannerTask task, String newStatus) async {
    await widget.repo.updateTask(task.id, {'status': newStatus});
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KanbanColumn(
          title: 'To Do',
          tasks: _tasksByStatus['open'] ?? [],
          color: Colors.blue,
          onTaskTap: widget.onTaskTap,
          onTaskMove: (task) => _updateTaskStatus(task, 'in_progress'),
        ),
        _KanbanColumn(
          title: 'In Progress',
          tasks: _tasksByStatus['in_progress'] ?? [],
          color: Colors.orange,
          onTaskTap: widget.onTaskTap,
          onTaskMove: (task) => _updateTaskStatus(task, 'done'),
        ),
        _KanbanColumn(
          title: 'Done',
          tasks: _tasksByStatus['done'] ?? [],
          color: Colors.green,
          onTaskTap: widget.onTaskTap,
          onTaskMove: null,
        ),
      ],
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final List<PlannerTask> tasks;
  final Color color;
  final ValueChanged<PlannerTask> onTaskTap;
  final ValueChanged<PlannerTask>? onTaskMove;

  const _KanbanColumn({
    required this.title,
    required this.tasks,
    required this.color,
    required this.onTaskTap,
    this.onTaskMove,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text('${tasks.length}'),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: color),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(task.title),
                      subtitle: task.dueAt != null
                          ? Text(DateFormat('d MMM', 'ms_MY').format(task.dueAt!))
                          : null,
                      trailing: onTaskMove != null
                          ? IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () => onTaskMove!(task),
                            )
                          : null,
                      onTap: () => onTaskTap(task),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

