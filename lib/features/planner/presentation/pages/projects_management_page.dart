import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/planner_project.dart';
import '../../../../data/repositories/planner_tasks_repository_supabase.dart';

class ProjectsManagementPage extends StatefulWidget {
  const ProjectsManagementPage({super.key});

  @override
  State<ProjectsManagementPage> createState() => _ProjectsManagementPageState();
}

class _ProjectsManagementPageState extends State<ProjectsManagementPage> {
  final _repo = PlannerTasksRepositorySupabase();
  List<PlannerProject> _projects = [];
  bool _loading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    try {
      final projects = await _repo.listProjects(includeArchived: _showArchived);
      if (mounted) {
        setState(() {
          _projects = projects;
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

  Future<void> _showCreateProject() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedColor;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Projek'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Projek *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
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
              const SizedBox(height: 16),
              const Text('Warna:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _ColorOption('#FF5722', selectedColor, (c) => selectedColor = c),
                  _ColorOption('#2196F3', selectedColor, (c) => selectedColor = c),
                  _ColorOption('#4CAF50', selectedColor, (c) => selectedColor = c),
                  _ColorOption('#FFC107', selectedColor, (c) => selectedColor = c),
                  _ColorOption('#9C27B0', selectedColor, (c) => selectedColor = c),
                  _ColorOption('#00BCD4', selectedColor, (c) => selectedColor = c),
                ],
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

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        await _repo.createProject(
          name: nameController.text.trim(),
          description: descController.text.trim().isEmpty ? null : descController.text.trim(),
          color: selectedColor,
        );
        _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projek berjaya dicipta')),
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

  Future<void> _archiveProject(PlannerProject project) async {
    try {
      await _repo.archiveProject(project.id);
      _loadProjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projek berjaya diarkibkan')),
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

  Future<void> _deleteProject(PlannerProject project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Projek'),
        content: Text('Adakah anda pasti mahu padam projek "${project.name}"? Tugasan yang berkaitan tidak akan dipadam.'),
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
        await _repo.deleteProject(project.id);
        _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Projek berjaya dipadam')),
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
        title: const Text('Urus Projek'),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.folder : Icons.archive),
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _loadProjects();
            },
            tooltip: _showArchived ? 'Tunjukkan Aktif' : 'Tunjukkan Diarkibkan',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Tiada projek',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: project.color != null
                              ? Color(int.parse(project.color!.replaceFirst('#', '0xFF')))
                              : AppColors.primary,
                          child: Icon(
                            project.icon != null
                                ? _getIconData(project.icon!)
                                : Icons.folder,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(project.name),
                        subtitle: project.description != null
                            ? Text(
                                project.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (project.isArchived)
                              const Chip(
                                label: Text('Diarkibkan'),
                                backgroundColor: Colors.grey,
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProject(project),
                            ),
                          ],
                        ),
                        onTap: project.isArchived
                            ? null
                            : () => _archiveProject(project),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProject,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Projek'),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'work': Icons.work,
      'personal': Icons.person,
      'shopping': Icons.shopping_cart,
      'health': Icons.favorite,
      'finance': Icons.attach_money,
      'home': Icons.home,
    };
    return iconMap[iconName] ?? Icons.folder;
  }
}

class _ColorOption extends StatelessWidget {
  final String color;
  final String? selectedColor;
  final ValueChanged<String> onSelected;

  const _ColorOption(this.color, this.selectedColor, this.onSelected);

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () => onSelected(color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.transparent,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}


