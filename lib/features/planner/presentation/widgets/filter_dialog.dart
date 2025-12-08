import 'package:flutter/material.dart';

import '../../../../data/models/planner_category.dart';
import '../../../../data/models/planner_project.dart';

class FilterDialog extends StatefulWidget {
  final List<PlannerCategory> categories;
  final List<PlannerProject> projects;
  final String? currentCategoryId;
  final String? currentProjectId;
  final String? currentStatus;

  const FilterDialog({
    required this.categories,
    required this.projects,
    this.currentCategoryId,
    this.currentProjectId,
    this.currentStatus,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String? _selectedCategoryId;
  String? _selectedProjectId;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.currentCategoryId;
    _selectedProjectId = widget.currentProjectId;
    _selectedStatus = widget.currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tapis Tugasan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status filter
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(value: null, child: Text('Semua')),
                DropdownMenuItem(value: 'open', child: Text('Buka')),
                DropdownMenuItem(value: 'in_progress', child: Text('Sedang')),
                DropdownMenuItem(value: 'done', child: Text('Selesai')),
                DropdownMenuItem(value: 'snoozed', child: Text('Tunda')),
              ],
              onChanged: (v) => setState(() => _selectedStatus = v),
            ),
            const SizedBox(height: 16),
            // Category filter
            if (widget.categories.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Semua')),
                  ...widget.categories.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
            if (widget.categories.isNotEmpty) const SizedBox(height: 16),
            // Project filter
            if (widget.projects.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Projek',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Semua')),
                  ...widget.projects.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedProjectId = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedCategoryId = null;
              _selectedProjectId = null;
              _selectedStatus = null;
            });
          },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            {
              'categoryId': _selectedCategoryId,
              'projectId': _selectedProjectId,
              'status': _selectedStatus,
            },
          ),
          child: const Text('Guna'),
        ),
      ],
    );
  }
}

