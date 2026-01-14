import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/repositories/recipe_document_repository.dart';
import '../../../../data/models/recipe_document.dart';
import 'edit_recipe_document_page.dart';
import '../../../subscription/widgets/subscription_guard.dart';

class RecipeDocumentDetailPage extends StatefulWidget {
  final String documentId;

  const RecipeDocumentDetailPage({
    super.key,
    required this.documentId,
  });

  @override
  State<RecipeDocumentDetailPage> createState() =>
      _RecipeDocumentDetailPageState();
}

class _RecipeDocumentDetailPageState extends State<RecipeDocumentDetailPage> {
  final _repo = RecipeDocumentRepository();
  RecipeDocument? _document;
  bool _loading = true;
  String? _fileUrl;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final document = await _repo.getById(widget.documentId);
      if (document == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumen tidak dijumpai'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _document = document;
        _loading = false;
      });

      // Update view stats
      await _repo.updateViewStats(document.id);

      // If file, get download URL
      if (document.isFile && document.filePath != null) {
        try {
          final url = await _repo.getFileUrl(document.filePath!);
          setState(() {
            _fileUrl = url;
          });
        } catch (e) {
          print('Error getting file URL: $e');
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavourite() async {
    if (_document == null) return;

    try {
      final updated = await _repo.toggleFavourite(_document!.id);
      setState(() {
        _document = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument() async {
    if (_document == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Dokumen'),
        content: Text('Adakah anda pasti mahu memadam "${_document!.title}"? Tindakan ini tidak boleh dibatalkan.'),
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
      // PHASE: Subscriber Expired System - Protect delete action
      await requirePro(context, 'Padam Dokumen Resepi', () async {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Memadam dokumen...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }

        try {
          await _repo.delete(_document!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumen telah dipadam'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          String errorMessage = 'Gagal memadam dokumen';
          
          // Provide user-friendly error messages
          if (e.toString().contains('not authenticated')) {
            errorMessage = 'Sila log masuk semula';
          } else if (e.toString().contains('not found')) {
            errorMessage = 'Dokumen tidak dijumpai';
          } else if (e.toString().contains('permission')) {
            errorMessage = 'Anda tidak mempunyai kebenaran untuk memadam dokumen ini';
          } else {
            errorMessage = 'Ralat: ${e.toString()}';
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
      });
    }
  }

  Future<void> _editDocument() async {
    if (_document == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRecipeDocumentPage(document: _document!),
      ),
    );

    if (result == true && mounted) {
      // Reload document after edit
      await _loadDocument();
    }
  }

  Future<void> _copyText() async {
    if (_document == null || _document!.textContent == null) return;

    await Clipboard.setData(ClipboardData(text: _document!.textContent!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resepi telah disalin ke clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openFile() async {
    if (_fileUrl == null) return;

    try {
      final uri = Uri.parse(_fileUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_document == null) {
      return const Scaffold(
        body: Center(child: Text('Document not found')),
      );
    }

    final doc = _document!;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.title),
        actions: [
          IconButton(
            icon: Icon(doc.isFavourite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavourite,
            tooltip: doc.isFavourite ? 'Buang dari Favorit' : 'Tambah ke Favorit',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              if (doc.isText)
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy, size: 20),
                      SizedBox(width: 8),
                      Text('Copy Text'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Padam', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                _editDocument();
              } else if (value == 'copy') {
                _copyText();
              } else if (value == 'delete') {
                _deleteDocument();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Metadata
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: doc.isFile ? Colors.blue[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            doc.displayIcon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (doc.source != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Sumber: ${doc.source}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (doc.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      doc.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                  if (doc.isFile && doc.fileName != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${doc.fileName} • ${doc.formattedFileSize ?? ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Content
          if (doc.isText && doc.textContent != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectableText(
                  doc.textContent!,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            )
          else if (doc.isFile && _fileUrl != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      doc.fileType == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fail PDF/Gambar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _openFile,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Buka Fail'),
                    ),
                  ],
                ),
              ),
            )
          else if (doc.isFile)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
