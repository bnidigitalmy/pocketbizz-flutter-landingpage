import 'package:flutter/material.dart';

import '../../../../data/models/planner_task_template.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';

class TemplatesManagementPage extends StatefulWidget {
  const TemplatesManagementPage({super.key});

  @override
  State<TemplatesManagementPage> createState() => _TemplatesManagementPageState();
}

class _TemplatesManagementPageState extends State<TemplatesManagementPage> {
  final _repo = PlannerTasksRepositorySupabase();
  List<PlannerTaskTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final templates = await _repo.listTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
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

  Future<void> _showCreateTemplate() async {
    final nameController = TextEditingController();
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Templat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Templat *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk Tugasan *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Penerangan',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
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
      ),
    );

    if (result == true &&
        nameController.text.trim().isNotEmpty &&
        titleController.text.trim().isNotEmpty) {
      try {
        await _repo.createTemplate(
          name: nameController.text.trim(),
          title: titleController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
        );
        _loadTemplates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Templat berjaya dicipta')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _useTemplate(PlannerTaskTemplate template) async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guna Templat'),
        content: const Text('Pilih tarikh due untuk tugasan baru:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                Navigator.pop(context, picked);
              }
            },
            child: const Text('Pilih Tarikh'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _repo.createTaskFromTemplate(template.id, result);
        if (mounted) {
          Navigator.pop(context); // Close templates page
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tugasan berjaya dicipta dari templat')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTemplate(PlannerTaskTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Templat'),
        content: Text('Adakah anda pasti mahu padam templat "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repo.deleteTemplate(template.id);
        _loadTemplates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Templat berjaya dipadam')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Urus Templat'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Tiada templat',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.description, size: 32),
                        title: Text(template.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tajuk: ${template.title}'),
                            if (template.description != null)
                              Text(
                                template.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (template.subtasks.isNotEmpty)
                              Text('${template.subtasks.length} subtasks'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_task, color: Colors.green),
                              onPressed: () => _useTemplate(template),
                              tooltip: 'Guna Templat',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTemplate(template),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTemplate,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Templat'),
      ),
    );
  }
}


