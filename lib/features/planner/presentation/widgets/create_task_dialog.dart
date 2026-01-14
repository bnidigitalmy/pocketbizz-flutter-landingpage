import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/planner_task.dart';
import '../../../../data/models/planner_category.dart';
import '../../../../data/models/planner_project.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';
import '../../../subscription/widgets/subscription_guard.dart';

class CreateTaskDialog extends StatefulWidget {
  final PlannerTasksRepositorySupabase repo;
  final String? initialCategoryId;
  final String? initialProjectId;

  const CreateTaskDialog({
    super.key,
    required this.repo,
    this.initialCategoryId,
    this.initialProjectId,
  });

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String _priority = 'normal';
  String? _selectedCategoryId;
  String? _selectedProjectId;
  List<String> _tags = [];
  double? _estimatedHours;
  bool _isRecurring = false;
  String? _recurrencePattern;
  int? _recurrenceInterval = 1;

  List<PlannerCategory> _categories = [];
  List<PlannerProject> _projects = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _selectedProjectId = widget.initialProjectId;
    _loadCategoriesAndProjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategoriesAndProjects() async {
    try {
      final results = await Future.wait([
        widget.repo.listCategories(),
        widget.repo.listProjects(),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0] as List<PlannerCategory>;
          _projects = results[1] as List<PlannerProject>;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    await requirePro(context, 'Cipta Tugasan', () async {
      setState(() => _loading = true);

      try {
        DateTime? dueAt;
        if (_dueDate != null) {
          final time = _dueTime ?? const TimeOfDay(hour: 9, minute: 0);
          dueAt = DateTime(
            _dueDate!.year,
            _dueDate!.month,
            _dueDate!.day,
            time.hour,
            time.minute,
          );
        }

        final task = await widget.repo.createTask(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          dueAt: dueAt,
          priority: _priority,
          categoryId: _selectedCategoryId,
          projectId: _selectedProjectId,
          tags: _tags.isEmpty ? null : _tags,
          estimatedHours: _estimatedHours,
          isRecurring: _isRecurring,
          recurrencePattern: _isRecurring ? _recurrencePattern : null,
          recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
        );

        if (mounted && task != null) {
          Navigator.pop(context, task);
        }
      } catch (e) {
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Cipta Tugasan',
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
                const Text(
                  'Tambah Tugasan',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tajuk *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Penerangan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Due date & time
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _dueDate == null
                                ? 'Pilih tarikh'
                                : DateFormat('d MMM yyyy', 'ms_MY').format(_dueDate!),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _dueDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _dueTime == null
                                ? 'Pilih masa'
                                : _dueTime!.format(context),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setState(() => _dueTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Priority
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Keutamaan',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Rendah')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('Tinggi')),
                      DropdownMenuItem(value: 'critical', child: Text('Kritikal')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'normal'),
                  ),
                  const SizedBox(height: 16),
                  // Category
                  if (_categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tiada kategori'),
                        ),
                        ..._categories.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  if (_categories.isNotEmpty) const SizedBox(height: 16),
                  // Project
                  if (_projects.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Projek',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tiada projek'),
                        ),
                        ..._projects.map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                    ),
                  if (_projects.isNotEmpty) const SizedBox(height: 16),
                  // Estimated hours
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Anggaran masa (jam)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _estimatedHours = double.tryParse(v);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Recurring
                  CheckboxListTile(
                    title: const Text('Tugasan berulang'),
                    value: _isRecurring,
                    onChanged: (v) => setState(() => _isRecurring = v ?? false),
                  ),
                  if (_isRecurring) ...[
                    DropdownButtonFormField<String>(
                      value: _recurrencePattern,
                      decoration: const InputDecoration(
                        labelText: 'Pola ulangan',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Harian')),
                        DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
                        DropdownMenuItem(value: 'monthly', child: Text('Bulanan')),
                        DropdownMenuItem(value: 'yearly', child: Text('Tahunan')),
                      ],
                      onChanged: (v) => setState(() => _recurrencePattern = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Nota',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          // Footer buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveTask,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

