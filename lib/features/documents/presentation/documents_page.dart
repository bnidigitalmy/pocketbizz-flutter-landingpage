import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import '../../../core/services/document_storage_service.dart';
import '../../../core/theme/app_colors.dart';

/// Documents Page
/// View and manage all documents stored in Supabase Storage
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<DocumentMetadata> _documents = [];
  bool _loading = false;
  String? _error;
  String? _selectedDocumentType;

  final List<String> _documentTypes = [
    'all',
    'invoice',
    'thermal_invoice',
    'receipt_a5',
    'claim_statement',
    'purchase_order',
    'profit_loss_report',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDocumentType = 'all';
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final documents = await DocumentStorageService.listDocuments(
        documentType: _selectedDocumentType == 'all' ? null : _selectedDocumentType,
        limit: 200,
      );

      setState(() {
        _documents = documents;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadDocument(DocumentMetadata doc) async {
    try {
      final bytes = await DocumentStorageService.downloadDocument(doc.path);
      
      if (kIsWeb) {
        // Web: trigger download
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', doc.name)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Mobile: open in browser or share
        if (await canLaunchUrl(Uri.parse(doc.url))) {
          await launchUrl(Uri.parse(doc.url), mode: LaunchMode.externalApplication);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dokumen berjaya dimuat turun'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(DocumentMetadata doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Dokumen'),
        content: Text('Adakah anda pasti mahu memadam "${doc.name}"?'),
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

    if (confirm == true) {
      try {
        await DocumentStorageService.deleteDocument(doc.path);
        await _loadDocuments(); // Refresh list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dokumen berjaya dipadam'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getDocumentTypeLabel(String type) {
    switch (type) {
      case 'invoice':
        return 'Invois';
      case 'thermal_invoice':
        return 'Invois Thermal';
      case 'receipt_a5':
        return 'Resit A5';
      case 'claim_statement':
        return 'Penyata Tuntutan';
      case 'purchase_order':
        return 'Pesanan Belian';
      case 'profit_loss_report':
        return 'Laporan Untung Rugi';
      default:
        return type;
    }
  }

  IconData _getDocumentTypeIcon(String type) {
    switch (type) {
      case 'all':
        return Icons.filter_list;
      case 'invoice':
        return Icons.receipt_long;
      case 'thermal_invoice':
        return Icons.receipt;
      case 'receipt_a5':
        return Icons.description_outlined;
      case 'claim_statement':
        return Icons.description;
      case 'purchase_order':
        return Icons.shopping_cart;
      case 'profit_loss_report':
        return Icons.assessment;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips - Improved design
          Container(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 10 : 12,
              horizontal: isMobile ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _documentTypes.map((type) {
                  final isSelected = _selectedDocumentType == type;
                  final label = type == 'all' ? 'Semua' : _getDocumentTypeLabel(type);
                  final icon = _getDocumentTypeIcon(type);
                  
                  return Padding(
                    padding: EdgeInsets.only(right: isMobile ? 6 : 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDocumentType = type;
                          });
                          _loadDocuments();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: isMobile ? 16 : 18,
                                color: isSelected ? Colors.white : AppColors.primary,
                              ),
                              SizedBox(width: isMobile ? 6 : 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Error: $_error',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDocuments,
                              child: const Text('Cuba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _documents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Tiada dokumen',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Dokumen akan disimpan secara automatik\napabila anda menjana PDF',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDocuments,
                            child: ListView.builder(
                              itemCount: _documents.length,
                              itemBuilder: (context, index) {
                                final doc = _documents[index];
                                return Card(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 8 : 12,
                                    vertical: isMobile ? 4 : 6,
                                  ),
                                  elevation: 1,
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 16,
                                      vertical: isMobile ? 6 : 8,
                                    ),
                                    dense: isMobile,
                                    leading: CircleAvatar(
                                      radius: isMobile ? 20 : 24,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      child: Icon(
                                        _getDocumentTypeIcon(doc.documentType),
                                        color: AppColors.primary,
                                        size: isMobile ? 18 : 20,
                                      ),
                                    ),
                                    title: Text(
                                      doc.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isMobile ? 13 : 14,
                                      ),
                                      maxLines: isMobile ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Padding(
                                      padding: EdgeInsets.only(top: isMobile ? 2 : 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getDocumentTypeLabel(doc.documentType),
                                            style: TextStyle(
                                              fontSize: isMobile ? 11 : 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: isMobile ? 2 : 4),
                                          isMobile
                                              ? Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 10,
                                                          color: Colors.grey[500],
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            DateFormat('dd MMM yyyy, hh:mm a')
                                                                .format(doc.createdAt),
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              color: Colors.grey[500],
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.storage,
                                                          size: 10,
                                                          color: Colors.grey[500],
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          doc.sizeFormatted,
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: Colors.grey[500],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                )
                                              : Wrap(
                                                  spacing: 12,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.calendar_today,
                                                          size: 11,
                                                          color: Colors.grey[500],
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          DateFormat('dd MMM yyyy, hh:mm a')
                                                              .format(doc.createdAt),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey[500],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.storage,
                                                          size: 11,
                                                          color: Colors.grey[500],
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          doc.sizeFormatted,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey[500],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    ),
                                    trailing: PopupMenuButton(
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'download',
                                          child: const Row(
                                            children: [
                                              Icon(Icons.download, size: 20),
                                              SizedBox(width: 8),
                                              Text('Muat Turun'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: const Row(
                                            children: [
                                              Icon(Icons.delete, size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Padam', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'download') {
                                          _downloadDocument(doc);
                                        } else if (value == 'delete') {
                                          _deleteDocument(doc);
                                        }
                                      },
                                    ),
                                    onTap: () => _downloadDocument(doc),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

