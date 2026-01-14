import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../data/repositories/recipe_document_repository.dart';
import '../../../../data/repositories/recipe_document_category_repository.dart';
import '../../../../data/models/recipe_document.dart';
import '../../../../data/models/recipe_document_category.dart';
import '../../../subscription/widgets/subscription_guard.dart';

class AddFileRecipePage extends StatefulWidget {
  const AddFileRecipePage({super.key});

  @override
  State<AddFileRecipePage> createState() => _AddFileRecipePageState();
}

class _AddFileRecipePageState extends State<AddFileRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = RecipeDocumentRepository();
  final _categoryRepo = RecipeDocumentCategoryRepository();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
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
    _descriptionController.dispose();
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        
        // Check file size (10MB limit)
        if (file.size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saiz fail terlalu besar. Maksimum 10MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
          _fileBytes = file.bytes;
          // Auto-fill title from filename
          if (_titleController.text.isEmpty) {
            _titleController.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _getFileType(String? extension) {
    if (extension == null) return null;
    final ext = extension.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (['jpg', 'jpeg'].contains(ext)) return 'jpg';
    if (ext == 'png') return 'png';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null || _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih fail terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // PHASE: Subscriber Expired System - Protect upload action
    await requirePro(context, 'Muat Naik Dokumen Resepi', () async {
      setState(() => _loading = true);

      try {
      // Upload file to storage
      final fileExtension = _selectedFile!.extension ?? '';
      final fileType = _getFileType(fileExtension);
      final contentType = fileType == 'pdf'
          ? 'application/pdf'
          : fileType == 'png'
              ? 'image/png'
              : 'image/jpeg';

      final filePath = await _repo.uploadFile(
        fileName: _selectedFile!.name,
        fileBytes: _fileBytes!,
        contentType: contentType,
      );

      // Create document record
      final document = RecipeDocument(
        id: '',
        businessOwnerId: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        contentType: 'file',
        fileName: _selectedFile!.name,
        filePath: filePath,
        fileType: fileType,
        fileSize: _selectedFile!.size,
        uploadedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repo.create(document);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumen berjaya dimuat naik!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Muat Naik Dokumen Resepi',
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
        title: const Text('Upload File Resepi'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // File picker
            Card(
              child: InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null
                            ? Icons.check_circle
                            : Icons.upload_file,
                        size: 48,
                        color: _selectedFile != null
                            ? Colors.green
                            : Colors.blue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFile != null
                            ? _selectedFile!.name
                            : '📎 Pilih File',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tekan untuk tukar fail',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'PDF, JPG, atau PNG\n(Maks: 10MB)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

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
