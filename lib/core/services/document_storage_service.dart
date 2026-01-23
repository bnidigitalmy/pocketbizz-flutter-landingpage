import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_client.dart';
import 'package:intl/intl.dart';

/// Service for handling document (PDF) uploads to Supabase Storage
/// 
/// This service automatically backs up all generated PDFs to Supabase Storage
/// for centralized access and backup purposes.
class DocumentStorageService {
  static const String _bucketName = 'user-documents';
  
  /// Upload PDF document to Supabase Storage
  /// 
  /// Returns the storage path and public URL of the uploaded document
  /// 
  /// [pdfBytes] - The PDF file as bytes
  /// [fileName] - The file name (e.g., "invoice-123.pdf")
  /// [documentType] - Type of document (invoice, claim, receipt, etc.)
  /// [relatedEntityType] - Related entity type (sale, claim, booking, delivery)
  /// [relatedEntityId] - Related entity ID
  /// [vendorName] - Optional vendor name for organization
  /// 
  /// Returns: Map with 'path' and 'url' keys
  static Future<Map<String, String>> uploadDocument({
    required Uint8List pdfBytes,
    required String fileName,
    required String documentType, // 'invoice', 'claim_statement', 'receipt', etc.
    String? relatedEntityType, // 'sale', 'claim', 'booking', 'delivery'
    String? relatedEntityId,
    String? vendorName,
  }) async {
    try {
      // Check if Supabase is initialized
      if (!Supabase.instance.isInitialized) {
        throw Exception('Supabase not initialized. Please wait for app to fully load.');
      }
      
      // Get current user ID
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated. Please login first.');
      }

      // Build storage path: {userId}/{documentType}/{year}/{month}/{fileName}
      final now = DateTime.now();
      final year = now.year.toString();
      final month = DateFormat('MM').format(now);
      
      // Organize by document type and date
      String storagePath;
      if (vendorName != null && vendorName.isNotEmpty) {
        // Include vendor name in path for better organization
        final sanitizedVendorName = _sanitizeFileName(vendorName);
        storagePath = '$userId/$documentType/$year/$month/$sanitizedVendorName/$fileName';
      } else {
        storagePath = '$userId/$documentType/$year/$month/$fileName';
      }

      // Ensure path doesn't have double slashes
      storagePath = storagePath.replaceAll(RegExp(r'/+'), '/');

      if (kIsWeb) {
        // For web: use HTTP PUT with proper headers
        final accessToken = supabase.auth.currentSession?.accessToken;
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('User not authenticated. Please login first.');
        }
        
        final encodedPath = Uri.encodeComponent(storagePath);
        // Get Supabase URL from environment (required)
        // For web builds, use fallback if .env is not available
        String? supabaseUrl = dotenv.env['SUPABASE_URL'];
        String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
        
        // Fallback for web production builds
        if (kIsWeb && (supabaseUrl == null || supabaseAnonKey == null)) {
          supabaseUrl = supabaseUrl ?? 'https://gxllowlurizrkvpdircw.supabase.co';
          supabaseAnonKey = supabaseAnonKey ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs';
        }
        
        if (supabaseUrl == null || supabaseAnonKey == null) {
          throw Exception('SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file');
        }
        
        final storageUrl = '$supabaseUrl/storage/v1/object/$_bucketName/$encodedPath';
        
        // Upload using HTTP PUT
        final response = await http.put(
          Uri.parse(storageUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/pdf',
            'apikey': supabaseAnonKey,
            'x-upsert': 'false',
            'Cache-Control': 'max-age=3600',
          },
          body: pdfBytes,
        );
        
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
        }
      } else {
        // For mobile/desktop: use Supabase Storage API
        // Retry logic for NotInitializedError
        int retries = 0;
        const maxRetries = 3;
        while (retries < maxRetries) {
          try {
            // Check initialization before each attempt
            if (!Supabase.instance.isInitialized) {
              if (retries < maxRetries - 1) {
                await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
                retries++;
                continue;
              }
              throw Exception('Supabase not initialized after $maxRetries retries.');
            }
            
            await supabase.storage
                .from(_bucketName)
                .uploadBinary(
                  storagePath,
                  pdfBytes,
                  fileOptions: FileOptions(
                    contentType: 'application/pdf',
                    upsert: false,
                  ),
                );
            break; // Success, exit retry loop
          } catch (e) {
            if (e.toString().contains('NotInitializedError') && retries < maxRetries - 1) {
              await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
              retries++;
              continue;
            }
            rethrow; // Re-throw if not NotInitializedError or max retries reached
          }
        }
      }

      // Get signed URL (bucket is private, so we need signed URL)
      // Signed URL expires in 7 days (604800 seconds)
      // Retry logic for NotInitializedError
      int urlRetries = 0;
      const maxUrlRetries = 3;
      String signedUrl = '';
      
      while (urlRetries < maxUrlRetries) {
        try {
          // Check initialization before each attempt
          if (!Supabase.instance.isInitialized) {
            if (urlRetries < maxUrlRetries - 1) {
              await Future.delayed(Duration(milliseconds: 500 * (urlRetries + 1)));
              urlRetries++;
              continue;
            }
            throw Exception('Supabase not initialized when creating signed URL after $maxUrlRetries retries.');
          }
          
          signedUrl = await supabase.storage
              .from(_bucketName)
              .createSignedUrl(storagePath, 604800);
          break; // Success, exit retry loop
        } catch (e) {
          if (e.toString().contains('NotInitializedError') && urlRetries < maxUrlRetries - 1) {
            await Future.delayed(Duration(milliseconds: 500 * (urlRetries + 1)));
            urlRetries++;
            continue;
          }
          rethrow; // Re-throw if not NotInitializedError or max retries reached
        }
      }

      print('✅ Document uploaded to Supabase Storage: $storagePath');
      
      return {
        'path': storagePath,
        'url': signedUrl,
      };
    } catch (e) {
      // Check if it's a NotInitializedError
      final errorString = e.toString();
      if (errorString.contains('NotInitializedError') || 
          errorString.contains('not initialized')) {
        print('⚠️ Supabase Storage not ready yet (NotInitializedError). This is non-critical for backup.');
        // For silent uploads, don't rethrow - just log
        throw Exception('Supabase Storage not initialized. Please wait for app to fully load.');
      }
      print('❌ Failed to upload document to Supabase Storage: $e');
      rethrow;
    }
  }

  /// Upload document silently (non-blocking, catches errors)
  /// 
  /// This method is designed to be called after PDF generation
  /// without blocking the main flow. Errors are logged but not thrown.
  static Future<void> uploadDocumentSilently({
    required Uint8List pdfBytes,
    required String fileName,
    required String documentType,
    String? relatedEntityType,
    String? relatedEntityId,
    String? vendorName,
  }) async {
    try {
      // Check if Supabase is initialized before attempting upload
      if (!Supabase.instance.isInitialized) {
        print('⚠️ Supabase not initialized - skipping document backup (non-critical)');
        return; // Silently skip if not initialized
      }
      
      await uploadDocument(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: documentType,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        vendorName: vendorName,
      );
      print('✅ Document backed up to Supabase Storage: $fileName');
    } catch (e) {
      // Log error but don't throw - backup is optional
      final errorString = e.toString();
      if (errorString.contains('NotInitializedError') || 
          errorString.contains('not initialized')) {
        print('⚠️ Supabase Storage not ready - skipping backup (non-critical)');
      } else {
        print('⚠️ Failed to backup document to Supabase Storage (non-critical): $e');
      }
    }
  }

  /// List documents for current user
  /// 
  /// [documentType] - Optional filter by document type
  /// [limit] - Maximum number of documents to return (default: 100)
  /// 
  /// Returns: List of document metadata
  static Future<List<DocumentMetadata>> listDocuments({
    String? documentType,
    int limit = 100,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated. Please login first.');
      }

      // Build path prefix
      String pathPrefix = userId;
      if (documentType != null) {
        pathPrefix = '$userId/$documentType';
      }

      // Recursively list all files
      final allFiles = <DocumentMetadata>[];
      await _listFilesRecursively(pathPrefix, documentType, allFiles);

      // Sort by created_at descending and limit results
      allFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final limitedFiles = limit > 0 ? allFiles.take(limit).toList() : allFiles;

      return limitedFiles;
    } catch (e) {
      print('❌ Failed to list documents: $e');
      rethrow;
    }
  }

  /// Recursively list all files in storage
  static Future<void> _listFilesRecursively(
    String pathPrefix,
    String? documentType,
    List<DocumentMetadata> allFiles,
  ) async {
    try {
      // List items in current path
      final items = await supabase.storage
          .from(_bucketName)
          .list(path: pathPrefix);

      for (final item in items) {
        // Check if it's a folder: folders typically don't have id or have metadata.size == null
        // Files have id and metadata with size
        final isFolder = item.id == null || 
                        (item.metadata == null || 
                         (item.metadata!['size'] == null && !item.name.contains('.')));
        
        if (isFolder) {
          // It's a folder, recurse into it
          final folderPath = pathPrefix.isEmpty ? item.name : '$pathPrefix/${item.name}';
          await _listFilesRecursively(folderPath, documentType, allFiles);
        } else {
          // It's a file - only add if it's a PDF
          if (item.name.toLowerCase().endsWith('.pdf')) {
            final filePath = pathPrefix.isEmpty ? item.name : '$pathPrefix/${item.name}';
            
            // Parse createdAt
            DateTime createdAt;
            if (item.createdAt is DateTime) {
              createdAt = item.createdAt as DateTime;
            } else if (item.createdAt is String) {
              createdAt = DateTime.tryParse(item.createdAt as String) ?? DateTime.now();
            } else {
              createdAt = DateTime.now();
            }
            
            // Parse updatedAt
            DateTime updatedAt;
            if (item.updatedAt is DateTime) {
              updatedAt = item.updatedAt as DateTime;
            } else if (item.updatedAt is String) {
              updatedAt = DateTime.tryParse(item.updatedAt as String) ?? DateTime.now();
            } else {
              updatedAt = DateTime.now();
            }
            
            allFiles.add(DocumentMetadata(
              name: item.name,
              path: filePath,
              size: item.metadata?['size'] is int ? item.metadata!['size'] as int : 0,
              createdAt: createdAt,
              updatedAt: updatedAt,
              url: supabase.storage.from(_bucketName).getPublicUrl(filePath),
            ));
          }
        }
      }
    } catch (e) {
      // If folder doesn't exist or access denied, just skip it
      print('⚠️ Error listing path $pathPrefix: $e');
    }
  }

  /// Download document from Supabase Storage
  /// 
  /// [path] - Storage path of the document
  /// 
  /// Returns: Document bytes
  static Future<Uint8List> downloadDocument(String path) async {
    try {
      final bytes = await supabase.storage
          .from(_bucketName)
          .download(path);
      
      return bytes;
    } catch (e) {
      print('❌ Failed to download document: $e');
      rethrow;
    }
  }

  /// Delete document from Supabase Storage
  /// 
  /// [path] - Storage path of the document
  static Future<void> deleteDocument(String path) async {
    try {
      await supabase.storage
          .from(_bucketName)
          .remove([path]);
      
      print('✅ Document deleted from Supabase Storage: $path');
    } catch (e) {
      print('❌ Failed to delete document: $e');
      rethrow;
    }
  }

  /// Get document URL
  /// 
  /// [path] - Storage path of the document
  /// 
  /// Returns: Public URL of the document
  static String getDocumentUrl(String path) {
    return supabase.storage
        .from(_bucketName)
        .getPublicUrl(path);
  }

  /// Sanitize file name to remove invalid characters
  static String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}

/// Document metadata model
class DocumentMetadata {
  final String name;
  final String path;
  final int size;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String url;

  DocumentMetadata({
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
    required this.updatedAt,
    required this.url,
  });

  String get sizeFormatted {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get documentType {
    // Extract document type from path
    final parts = path.split('/');
    if (parts.length >= 2) {
      return parts[1]; // userId/documentType/...
    }
    return 'unknown';
  }
}

