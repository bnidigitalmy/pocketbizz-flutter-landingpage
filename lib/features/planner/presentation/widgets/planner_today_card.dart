import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/planner_task.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';

class PlannerTodayCard extends StatefulWidget {
  const PlannerTodayCard({super.key, this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  State<PlannerTodayCard> createState() => _PlannerTodayCardState();
}

class _PlannerTodayCardState extends State<PlannerTodayCard> {
  final _repo = PlannerTasksRepositorySupabase();
  bool _loading = true;
  List<PlannerTask> _today = [];
  List<PlannerTask> _overdue = [];
  List<PlannerTask> _upcoming = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.listTasks(scope: 'today', limit: 5),
        _repo.listTasks(scope: 'overdue', limit: 5),
        _repo.listTasks(scope: 'upcoming', limit: 5),
      ]);
      if (!mounted) return;
      
      // Filter out auto-generated tasks (only show user-created tasks)
      final filterUserTasks = (List<PlannerTask> tasks) => 
        tasks.where((t) => !t.isAuto).toList();
      
      setState(() {
        _today = filterUserTasks(results[0]);
        _overdue = filterUserTasks(results[1]);
        _upcoming = filterUserTasks(results[2]);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final totalTasks = _overdue.length + _today.length + _upcoming.length;
    final display = [
      ..._overdue,
      ..._today,
      ..._upcoming,
    ].take(3).toList();

    // Hide card if no tasks (less stress, only show when needed)
    if (totalTasks == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: Colors.blue.shade50.withOpacity(0.3), // More subtle, less urgent
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tugas Hari Ini',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Rancangan harian anda',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Lihat Semua', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_overdue.length > 0)
                  _countChip('Tertunggak', _overdue.length, Colors.red.shade400),
                if (_today.length > 0)
                  _countChip('Hari ini', _today.length, Colors.orange.shade400),
                if (_upcoming.length > 0)
                  _countChip('Akan datang', _upcoming.length, Colors.blue.shade400),
              ],
            ),
            if (display.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...display.map((t) => _TaskRow(task: t)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final PlannerTask task;

  @override
  Widget build(BuildContext context) {
    final dueText = task.dueAt != null
        ? DateFormat('d MMM, h:mm a', 'ms_MY').format(task.dueAt!)
        : 'Tiada due';
    final isOverdue = task.isOverdue;
    final color = isOverdue
        ? Colors.red
        : (task.dueAt != null ? Colors.orange : AppColors.primary);
    final textColor = color is MaterialColor ? color.shade700 : color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(task.isAuto ? Icons.bolt : Icons.check_circle_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dueText,
            style: TextStyle(fontSize: 12, color: textColor),
          ),
        ],
      ),
    );
  }
}

