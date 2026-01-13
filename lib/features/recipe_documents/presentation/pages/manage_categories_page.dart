import 'package:flutter/material.dart';
import '../../../../data/repositories/recipe_document_category_repository.dart';
import '../../../../data/models/recipe_document_category.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final _repo = RecipeDocumentCategoryRepository();
  List<RecipeDocumentCategory> _categories = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final categories = await _repo.getAll();
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    String? selectedIcon;

    // Popular emojis for recipe categories
    final categoryEmojis = [
      '📁', '🎂', '🍰', '🍪', '🧁', '🍩', '🥧', '🍞',
      '🥐', '🥖', '🍕', '🍝', '🍜', '🍲', '🍛', '🍱',
      '🥘', '🍳', '🥗', '🥙', '🌮', '🌯', '🥪', '🍔',
      '🍟', '🍗', '🍖', '🥩', '🥓', '🍕', '🍤', '🍣',
      '🍨', '🍧', '🍦', '🥤', '🍹', '🍷', '🍸', '☕',
      '🍵', '🥛', '🧃', '🧉', '🧊', '🥨', '🥞', '🧇',
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Kategori Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kategori *',
                    hintText: 'Contoh: Kek',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                // Icon Selection Label
                const Text(
                  'Icon (Emoji) - Pilihan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                // Selected Emoji Display
                if (selectedIcon != null && selectedIcon!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Text(
                          selectedIcon!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Icon dipilih',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          color: Colors.blue[700],
                          onPressed: () {
                            setDialogState(() {
                              selectedIcon = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // Emoji Picker - Use Wrap instead of GridView to avoid intrinsic dimension issues
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: categoryEmojis.map((emoji) {
                          final isSelected = selectedIcon == emoji;
                          
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedIcon = emoji;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, <String, dynamic>{
                    'name': nameController.text.trim(),
                    'icon': selectedIcon,
                  });
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final category = RecipeDocumentCategory(
          id: '',
          businessOwnerId: '',
          name: result['name'] as String,
          icon: result['icon'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _repo.create(category);
        await _loadCategories();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kategori berjaya ditambah!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Ralat berlaku semasa menambah kategori';
          
          // Check for duplicate key error (unique constraint violation)
          final errorString = e.toString();
          if (errorString.contains('23505') || 
              errorString.contains('unique constraint') ||
              errorString.contains('duplicate key') ||
              errorString.contains('unique_category_per_user')) {
            errorMessage = 'Nama kategori ini sudah wujud. Sila gunakan nama lain.';
          } else if (errorString.contains('User not authenticated')) {
            errorMessage = 'Sila log masuk semula.';
          } else if (errorString.contains('PostgrestException')) {
            // Try to extract a more user-friendly message from PostgrestException
            if (errorString.contains('message:')) {
              final match = RegExp(r'message:\s*([^,]+)').firstMatch(errorString);
              if (match != null) {
                final extractedMsg = match.group(1)?.trim() ?? '';
                if (extractedMsg.isNotEmpty && !extractedMsg.contains('duplicate')) {
                  errorMessage = extractedMsg;
                }
              }
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(RecipeDocumentCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Kategori'),
        content: Text(
          'Adakah anda pasti mahu memadam kategori "${category.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.delete(category.id);
        await _loadCategories();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kategori telah dipadam'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Ralat berlaku semasa memadam kategori';
          
          final errorString = e.toString();
          if (errorString.contains('sedang digunakan')) {
            // Extract the user-friendly message from the exception
            final match = RegExp(r'Exception:\s*(.+)').firstMatch(errorString);
            if (match != null) {
              errorMessage = match.group(1)?.trim() ?? errorMessage;
            } else {
              errorMessage = 'Kategori ini sedang digunakan. Sila alihkan dokumen ke kategori lain terlebih dahulu.';
            }
          } else if (errorString.contains('User not authenticated')) {
            errorMessage = 'Sila log masuk semula.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Urus Kategori'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tiada kategori lagi',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddCategoryDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Kategori Pertama'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              category.displayIcon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(category.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCategory(category),
                          tooltip: 'Padam',
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategoryDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori'),
      ),
    );
  }
}
