import 'package:flutter/material.dart';
import '../../../../data/repositories/categories_repository_supabase_cached.dart';
import '../../../../data/models/category.dart';

class CategoryDropdown extends StatefulWidget {
  final String? initialValue;
  final Function(String?) onChanged;

  const CategoryDropdown({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

  @override
  State<CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<CategoryDropdown> {
  final _repo = CategoriesRepositorySupabaseCached();
  List<Category> _categories = [];
  bool _loading = true;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialValue;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      // Use cached repository - instant load from cache, syncs in background
      final categories = await _repo.getAllCached(
        limit: 100,
        onDataUpdated: (updatedCategories) {
          if (mounted) {
            setState(() {
              _categories = updatedCategories;
              // Validate selected category still exists
              if (_selectedCategory != null) {
                final exists = _categories.any((cat) => cat.name == _selectedCategory);
                if (!exists) {
                  _selectedCategory = null;
                  widget.onChanged(null);
                }
              }
            });
          }
        },
      );
      setState(() {
        _categories = categories;
        _loading = false;
        
        // Validate that selectedCategory exists in the list
        // If not, reset to null
        if (_selectedCategory != null) {
          final exists = _categories.any((cat) => cat.name == _selectedCategory);
          if (!exists) {
            _selectedCategory = null;
            widget.onChanged(null);
          }
        }
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LinearProgressIndicator();
    }

    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('No Category'),
        ),
        ..._categories.map((category) {
          return DropdownMenuItem<String>(
            value: category.name,
            child: Row(
              children: [
                if (category.icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(category.icon!),
                  ),
                Text(category.name),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() => _selectedCategory = value);
        widget.onChanged(value);
      },
    );
  }
}

