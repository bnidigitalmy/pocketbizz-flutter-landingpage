import 'package:flutter/material.dart';
import '../../../../data/repositories/recipe_document_repository.dart';
import '../../../../data/repositories/recipe_document_category_repository.dart';
import '../../../../data/models/recipe_document.dart';
import '../../../../data/models/recipe_document_category.dart';
import '../../../subscription/widgets/subscription_guard.dart';

class AddTextRecipePage extends StatefulWidget {
  const AddTextRecipePage({super.key});

  @override
  State<AddTextRecipePage> createState() => _AddTextRecipePageState();
}

class _AddTextRecipePageState extends State<AddTextRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = RecipeDocumentRepository();
  final _categoryRepo = RecipeDocumentCategoryRepository();
  final _titleController = TextEditingController();
  final _textContentController = TextEditingController();
  final _sourceController = TextEditingController();

  String? _selectedCategoryId;
  List<RecipeDocumentCategory> _categories = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textContentController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryRepo.getAll();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      // Ignore error, categories are optional
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // PHASE: Subscriber Expired System - Protect create action
    await requirePro(context, 'Tambah Resepi Text', () async {
      setState(() => _loading = true);

      try {
        final document = RecipeDocument(
          id: '',
          businessOwnerId: '',
          title: _titleController.text.trim(),
          categoryId: _selectedCategoryId,
          contentType: 'text',
          textContent: _textContentController.text.trim(),
          source: _sourceController.text.trim().isEmpty
              ? null
              : _sourceController.text.trim(),
          uploadedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _repo.create(document);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resepi berjaya disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah Resepi Text',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Resepi Text'),
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
              value: _selectedCategoryId,
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

            // Text content
            TextFormField(
              controller: _textContentController,
              decoration: const InputDecoration(
                labelText: 'Resepi *',
                hintText: 'Paste resepi di sini...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Sila paste resepi';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Copy resepi dari Facebook/WhatsApp dan paste di sini',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

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
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
