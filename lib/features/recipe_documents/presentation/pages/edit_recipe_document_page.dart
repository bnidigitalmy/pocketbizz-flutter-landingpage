import 'package:flutter/material.dart';
import '../../../../data/repositories/recipe_document_repository.dart';
import '../../../../data/repositories/recipe_document_category_repository.dart';
import '../../../../data/models/recipe_document.dart';
import '../../../../data/models/recipe_document_category.dart';
import '../../../subscription/widgets/subscription_guard.dart';

class EditRecipeDocumentPage extends StatefulWidget {
  final RecipeDocument document;

  const EditRecipeDocumentPage({
    super.key,
    required this.document,
  });

  @override
  State<EditRecipeDocumentPage> createState() => _EditRecipeDocumentPageState();
}

class _EditRecipeDocumentPageState extends State<EditRecipeDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = RecipeDocumentRepository();
  final _categoryRepo = RecipeDocumentCategoryRepository();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _textContentController = TextEditingController();
  final _sourceController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _selectedCategoryId;
  List<RecipeDocumentCategory> _categories = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.document.title;
    _descriptionController.text = widget.document.description ?? '';
    _textContentController.text = widget.document.textContent ?? '';
    _sourceController.text = widget.document.source ?? '';
    _tagsController.text = widget.document.tags.join(', ');
    // Don't set category yet - wait for categories to load
    _loadCategories().then((_) {
      // After categories load, validate and set category
      if (mounted) {
        final categoryId = widget.document.categoryId;
        if (categoryId != null) {
          // Check if category still exists
          final categoryExists = _categories.any((cat) => cat.id == categoryId);
          if (categoryExists) {
            setState(() {
              _selectedCategoryId = categoryId;
            });
          } else {
            // Category was deleted, set to null
            setState(() {
              _selectedCategoryId = null;
            });
          }
        } else {
          setState(() {
            _selectedCategoryId = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _textContentController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepo.getAll();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // PHASE: Subscriber Expired System - Protect edit action
    await requirePro(context, 'Kemaskini Dokumen Resepi', () async {
      setState(() => _loading = true);

      try {
      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Update document
      final updated = RecipeDocument(
        id: widget.document.id,
        businessOwnerId: widget.document.businessOwnerId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        contentType: widget.document.contentType,
        fileName: widget.document.fileName,
        filePath: widget.document.filePath,
        fileType: widget.document.fileType,
        fileSize: widget.document.fileSize,
        textContent: widget.document.isText
            ? _textContentController.text.trim()
            : widget.document.textContent,
        tags: tags,
        isFavourite: widget.document.isFavourite,
        linkedRecipeId: widget.document.linkedRecipeId,
        uploadedAt: widget.document.uploadedAt,
        lastViewedAt: widget.document.lastViewedAt,
        viewCount: widget.document.viewCount,
        source: _sourceController.text.trim().isEmpty
            ? null
            : _sourceController.text.trim(),
        createdAt: widget.document.createdAt,
        updatedAt: DateTime.now(),
      );

      await _repo.update(updated);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumen berjaya dikemaskini!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Kemaskini Dokumen Resepi',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isText = widget.document.isText;

    return Scaffold(
      appBar: AppBar(
        title: Text(isText ? 'Edit Resepi Text' : 'Edit Dokumen'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nama Resepi *',
                hintText: 'Contoh: Kek Coklat Mudah',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Sila masukkan nama resepi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategoryId != null &&
                      _categories.any((cat) => cat.id == _selectedCategoryId)
                  ? _selectedCategoryId
                  : null, // Set to null if category doesn't exist
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'Pilih kategori (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tiada kategori'),
                ),
                ..._categories.map((category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text('${category.displayIcon} ${category.name}'),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Penerangan (optional)',
                hintText: 'Tambah nota atau penerangan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Text content (only for text documents)
            if (isText) ...[
              TextFormField(
                controller: _textContentController,
                decoration: const InputDecoration(
                  labelText: 'Kandungan Resepi *',
                  hintText: 'Paste atau taip resepi di sini...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 15,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sila masukkan kandungan resepi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Source
            TextFormField(
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: 'Sumber (optional)',
                hintText: 'Contoh: Facebook Group PJJ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (optional)',
                hintText: 'kek, coklat, mudah (pisahkan dengan koma)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
                helperText: 'Pisahkan tags dengan koma',
              ),
            ),
            const SizedBox(height: 32),

            // File info (for file documents)
            if (!isText && widget.document.fileName != null) ...[
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fail: ${widget.document.fileName}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            if (widget.document.formattedFileSize != null)
                              Text(
                                widget.document.formattedFileSize!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Save button
            ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
