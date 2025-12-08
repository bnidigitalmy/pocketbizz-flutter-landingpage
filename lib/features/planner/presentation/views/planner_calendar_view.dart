import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/planner_task.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';

class PlannerCalendarView extends StatefulWidget {
  final PlannerTasksRepositorySupabase repo;
  final String? categoryId;
  final String? projectId;
  final ValueChanged<PlannerTask> onTaskTap;

  const PlannerCalendarView({
    super.key,
    required this.repo,
    this.categoryId,
    this.projectId,
    required this.onTaskTap,
  });

  @override
  State<PlannerCalendarView> createState() => _PlannerCalendarViewState();
}

class _PlannerCalendarViewState extends State<PlannerCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<PlannerTask>> _tasksByDate = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      // Load all tasks for the month
      final tasks = await widget.repo.listTasks(
        scope: 'upcoming',
        categoryId: widget.categoryId,
        projectId: widget.projectId,
        limit: 500,
      );
      
      // Also load today and overdue
      final todayTasks = await widget.repo.listTasks(scope: 'today', limit: 100);
      final overdueTasks = await widget.repo.listTasks(scope: 'overdue', limit: 100);
      
      final allTasks = [...tasks, ...todayTasks, ...overdueTasks];

      // Group by date
      final grouped = <DateTime, List<PlannerTask>>{};
      for (final task in allTasks) {
        if (task.dueAt != null) {
          final date = DateTime(
            task.dueAt!.year,
            task.dueAt!.month,
            task.dueAt!.day,
          );
          grouped.putIfAbsent(date, () => []).add(task);
        }
      }

      if (mounted) {
        setState(() {
          _tasksByDate = grouped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<PlannerTask> _getTasksForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _tasksByDate[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        TableCalendar<PlannerTask>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarFormat: _calendarFormat,
          eventLoader: _getTasksForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() => _calendarFormat = format);
          },
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
            _loadTasks(); // Reload when month changes
          },
        ),
        const Divider(),
        Expanded(
          child: _buildTaskList(),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    final tasks = _getTasksForDay(_selectedDay);
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'Tiada tugasan pada ${DateFormat('d MMM yyyy', 'ms_MY').format(_selectedDay)}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(task.title),
            subtitle: task.description != null
                ? Text(
                    task.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: task.dueAt != null
                ? Text(DateFormat('h:mm a', 'ms_MY').format(task.dueAt!))
                : null,
            onTap: () => widget.onTaskTap(task),
          ),
        );
      },
    );
  }
}


