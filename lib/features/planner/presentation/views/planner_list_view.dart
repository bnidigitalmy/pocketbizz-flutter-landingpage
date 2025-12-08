import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/planner_task.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';
import '../widgets/enhanced_task_card.dart';

class PlannerListView extends StatefulWidget {
  final PlannerTasksRepositorySupabase repo;
  final String scope;
  final String? categoryId;
  final String? projectId;
  final String? status;
  final String? searchQuery;
  final ValueChanged<PlannerTask> onTaskTap;

  const PlannerListView({
    super.key,
    required this.repo,
    required this.scope,
    this.categoryId,
    this.projectId,
    this.status,
    this.searchQuery,
    required this.onTaskTap,
  });

  @override
  State<PlannerListView> createState() => _PlannerListViewState();
}

class _PlannerListViewState extends State<PlannerListView> {
  List<PlannerTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void didUpdateWidget(PlannerListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        oldWidget.categoryId != widget.categoryId ||
        oldWidget.projectId != widget.projectId ||
        oldWidget.status != widget.status ||
        oldWidget.searchQuery != widget.searchQuery) {
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final tasks = await widget.repo.listTasks(
        scope: widget.scope == 'all' ? 'today' : widget.scope,
        categoryId: widget.categoryId,
        projectId: widget.projectId,
        status: widget.status,
        searchQuery: widget.searchQuery?.isEmpty ?? true ? null : widget.searchQuery,
      );
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Tiada tugasan',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return EnhancedTaskCard(
            task: task,
            onTap: () => widget.onTaskTap(task),
            onStatusChanged: () => _loadTasks(),
          );
        },
      ),
    );
  }
}

