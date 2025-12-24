import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/planner_task.dart';
import '../../../data/repositories/planner_tasks_repository_supabase.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> with SingleTickerProviderStateMixin {
  late final PlannerTasksRepositorySupabase _repo;
  late final TabController _tabController;

  final _tabs = const [
    Tab(text: 'Hari Ini'),
    Tab(text: 'Akan Datang'),
    Tab(text: 'Tertunggak'),
    Tab(text: 'Auto'),
  ];

  bool _loading = true;
  List<PlannerTask> _today = [];
  List<PlannerTask> _upcoming = [];
  List<PlannerTask> _overdue = [];
  List<PlannerTask> _auto = [];

  @override
  void initState() {
    super.initState();
    _repo = PlannerTasksRepositorySupabase();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.listTasks(scope: 'today'),
        _repo.listTasks(scope: 'upcoming'),
        _repo.listTasks(scope: 'overdue'),
        _repo.listTasks(scope: 'auto'),
      ]);

      if (!mounted) return;
      setState(() {
        _today = results[0];
        _upcoming = results[1];
        _overdue = results[2];
        _auto = results[3];
        _loading = false;
      });
      
      // Check tooltip after data loaded
      _checkAndShowTooltip();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal muat Planner')),
      );
    }
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _today.isNotEmpty || _upcoming.isNotEmpty || _overdue.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.planner,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.planner : TooltipContent.plannerEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  Future<void> _addManualTask() async {
    final titleController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Tugasan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk tugasan',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        selectedDate == null
                            ? 'Pilih tarikh'
                            : DateFormat('d MMM yyyy', 'ms_MY').format(selectedDate!),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        selectedTime == null
                            ? 'Pilih masa'
                            : selectedTime!.format(context),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result != true) return;
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan tajuk tugasan')),
      );
      return;
    }

    DateTime? dueAt;
    if (selectedDate != null) {
      final time = selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
      dueAt = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        time.hour,
        time.minute,
      );
    }

    await _repo.createTask(
      title: titleController.text.trim(),
      dueAt: dueAt,
      remindAt: dueAt?.subtract(const Duration(minutes: 30)),
    );

    _loadAll();
  }

  Future<void> _handleDone(PlannerTask task) async {
    await _repo.markDone(task.id);
    _loadAll();
  }

  Future<void> _handleSnooze(PlannerTask task, Duration duration) async {
    await _repo.snooze(task.id, duration);
    _loadAll();
  }

  Future<void> _handleDelete(PlannerTask task) async {
    await _repo.deleteTask(task.id);
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_today),
                _buildList(_upcoming),
                _buildList(_overdue),
                _buildList(_auto),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualTask,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Tambah Tugasan'),
      ),
    );
  }

  Widget _buildList(List<PlannerTask> items) {
    if (items.isEmpty) {
      return const Center(child: Text('Tiada tugasan'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final t = items[index];
        return _TaskCard(
          task: t,
          onDone: () => _handleDone(t),
          onSnooze: () => _handleSnooze(t, const Duration(hours: 4)),
          onDelete: () => _handleDelete(t),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onDone,
    required this.onSnooze,
    required this.onDelete,
  });

  final PlannerTask task;
  final VoidCallback onDone;
  final VoidCallback onSnooze;
  final VoidCallback onDelete;

  Color _statusColor(BuildContext context) {
    if (task.status == 'done') return Colors.green.shade100;
    if (task.isOverdue) return Colors.red.shade50;
    return Theme.of(context).colorScheme.surfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final dueText = task.dueAt != null
        ? DateFormat('d MMM, h:mm a', 'ms_MY').format(task.dueAt!)
        : 'Tiada due';

    final priorityColor = switch (task.priority) {
      'high' => Colors.orange,
      'critical' => Colors.red,
      'low' => Colors.blueGrey,
      _ => Colors.blue,
    };

    return Card(
      color: _statusColor(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.isAuto ? Icons.bolt : Icons.check_circle_outline,
                  color: task.isAuto ? Colors.amber.shade800 : AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Text(
                  dueText,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const Spacer(),
                if (task.isAuto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AUTO',
                      style: TextStyle(
                        color: Colors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check),
                  label: const Text('Tanda Selesai'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onSnooze,
                  icon: const Icon(Icons.snooze),
                  label: const Text('Tunda 4j'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


