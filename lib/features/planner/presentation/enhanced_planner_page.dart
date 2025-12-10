import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/planner_task.dart';
import '../../../data/models/planner_category.dart';
import '../../../data/models/planner_project.dart';
import '../../../data/repositories/planner_tasks_repository_supabase.dart';
import 'views/planner_list_view.dart';
import 'views/planner_calendar_view.dart';
import 'views/planner_kanban_view.dart';
import 'widgets/task_detail_bottom_sheet.dart';
import 'widgets/create_task_dialog.dart';
import 'pages/categories_management_page.dart';
import 'pages/projects_management_page.dart';
import 'pages/templates_management_page.dart';
import 'widgets/filter_dialog.dart';

class EnhancedPlannerPage extends StatefulWidget {
  const EnhancedPlannerPage({super.key});

  @override
  State<EnhancedPlannerPage> createState() => _EnhancedPlannerPageState();
}

class _EnhancedPlannerPageState extends State<EnhancedPlannerPage>
    with SingleTickerProviderStateMixin {
  late final PlannerTasksRepositorySupabase _repo;
  late final TabController _viewController;

  final _views = const [
    Tab(icon: Icon(Icons.list), text: 'Senarai'),
    Tab(icon: Icon(Icons.calendar_today), text: 'Kalendar'),
    Tab(icon: Icon(Icons.view_kanban), text: 'Kanban'),
  ];

  int _currentViewIndex = 0;
  String _currentScope = 'today';
  String? _selectedCategoryId;
  String? _selectedProjectId;
  String? _selectedStatus;
  String? _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repo = PlannerTasksRepositorySupabase();
    _viewController = TabController(length: _views.length, vsync: this);
    _viewController.addListener(() {
      setState(() => _currentViewIndex = _viewController.index);
    });
  }

  @override
  void dispose() {
    _viewController.dispose();
    super.dispose();
  }

  Future<void> _showCreateTask() async {
    final result = await showModalBottomSheet<PlannerTask?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskDialog(
        repo: _repo,
        initialCategoryId: _selectedCategoryId,
        initialProjectId: _selectedProjectId,
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugasan berjaya dicipta')),
      );
    }
  }

  Future<void> _showTaskDetail(PlannerTask task) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskDetailBottomSheet(
        task: task,
        repo: _repo,
        onUpdated: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'categories',
                child: ListTile(
                  leading: Icon(Icons.category),
                  title: Text('Urus Kategori'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'projects',
                child: ListTile(
                  leading: Icon(Icons.folder),
                  title: Text('Urus Projek'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'templates',
                child: ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Urus Templat'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'categories':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoriesManagementPage(),
                    ),
                  );
                  break;
                case 'projects':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProjectsManagementPage(),
                    ),
                  );
                  break;
                case 'templates':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TemplatesManagementPage(),
                    ),
                  );
                  break;
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _viewController,
          tabs: _views,
        ),
      ),
      body: Column(
        children: [
          // Scope selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ScopeChip(
                    label: 'Hari Ini',
                    value: 'today',
                    selected: _currentScope == 'today',
                    onSelected: (v) => setState(() => _currentScope = v),
                  ),
                  const SizedBox(width: 8),
                  _ScopeChip(
                    label: 'Tertunggak',
                    value: 'overdue',
                    selected: _currentScope == 'overdue',
                    onSelected: (v) => setState(() => _currentScope = v),
                  ),
                  const SizedBox(width: 8),
                  _ScopeChip(
                    label: 'Akan Datang',
                    value: 'upcoming',
                    selected: _currentScope == 'upcoming',
                    onSelected: (v) => setState(() => _currentScope = v),
                  ),
                  const SizedBox(width: 8),
                  _ScopeChip(
                    label: 'Sedang',
                    value: 'in_progress',
                    selected: _currentScope == 'in_progress',
                    onSelected: (v) => setState(() => _currentScope = v),
                  ),
                  const SizedBox(width: 8),
                  _ScopeChip(
                    label: 'Auto',
                    value: 'auto',
                    selected: _currentScope == 'auto',
                    onSelected: (v) => setState(() => _currentScope = v),
                  ),
                ],
              ),
            ),
          ),
          // View content
          Expanded(
            child: TabBarView(
              controller: _viewController,
              children: [
                PlannerListView(
                  repo: _repo,
                  scope: _currentScope,
                  categoryId: _selectedCategoryId,
                  projectId: _selectedProjectId,
                  status: _selectedStatus,
                  searchQuery: _searchQuery,
                  onTaskTap: _showTaskDetail,
                ),
                PlannerCalendarView(
                  repo: _repo,
                  categoryId: _selectedCategoryId,
                  projectId: _selectedProjectId,
                  onTaskTap: _showTaskDetail,
                ),
                PlannerKanbanView(
                  repo: _repo,
                  categoryId: _selectedCategoryId,
                  projectId: _selectedProjectId,
                  onTaskTap: _showTaskDetail,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTask,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Tambah Tugasan'),
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cari Tugasan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masukkan kata kunci...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Cari'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _searchQuery = result);
    }
  }

  Future<void> _showFilterDialog() async {
    final categories = await _repo.listCategories();
    final projects = await _repo.listProjects();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FilterDialog(
        categories: categories,
        projects: projects,
        currentCategoryId: _selectedCategoryId,
        currentProjectId: _selectedProjectId,
        currentStatus: _selectedStatus,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCategoryId = result['categoryId'] as String?;
        _selectedProjectId = result['projectId'] as String?;
        _selectedStatus = result['status'] as String?;
      });
    }
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  const _ScopeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }
}

