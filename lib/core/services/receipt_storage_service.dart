import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../supabase/supabase_client.dart';

/// Service for handling receipt image uploads to Supabase Storage (PRIVATE bucket)
class ReceiptStorageService {
  static const String _bucketName = 'receipts';
  
  /// Default signed URL expiry duration (7 days)
  static const int _signedUrlExpirySeconds = 604800;

  /// Upload receipt image to Supabase Storage
  /// 
  /// [imageBytes] - The image file as bytes (base64 decoded)
  /// [expenseId] - Optional expense ID to link the receipt
  /// 
  /// Returns the STORAGE PATH (not URL) for later signed URL generation
  static Future<String> uploadReceipt({
    required Uint8List imageBytes,
    String? expenseId,
  }) async {
    try {
      // Get current user ID
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = expenseId != null 
          ? 'receipt-$expenseId-$timestamp.jpg'
          : 'receipt-$timestamp.jpg';
      
      // Organize by user ID and date
      final now = DateTime.now();
      final datePath = '${now.year}/${now.month.toString().padLeft(2, '0')}';
      final storagePath = '$userId/$datePath/$fileName';

      if (kIsWeb) {
        // For web: use HTTP PUT with proper headers
        final accessToken = supabase.auth.currentSession?.accessToken;
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('User not authenticated. Please login first.');
        }
        
        // Get Supabase URL from environment (required)
        final supabaseUrl = dotenv.env['SUPABASE_URL'];
        final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
        
        if (supabaseUrl == null || supabaseAnonKey == null) {
          throw Exception('SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env file');
        }
        
        // Encode path properly for URL (each segment separately)
        final pathSegments = storagePath.split('/');
        final encodedSegments = pathSegments.map((s) => Uri.encodeComponent(s)).join('/');
        final storageUrl = '$supabaseUrl/storage/v1/object/$_bucketName/$encodedSegments';
        
        print('📤 Uploading receipt to: $storageUrl');
        print('   Storage path: $storagePath');
        print('   File size: ${imageBytes.length} bytes');
        
        // Upload using HTTP PUT
        final response = await http.put(
          Uri.parse(storageUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'image/jpeg',
            'apikey': supabaseAnonKey,
            'x-upsert': 'true', // Allow overwrite
          },
          body: imageBytes,
        );
        
        print('📥 Upload response: ${response.statusCode}');
        if (response.statusCode != 200 && response.statusCode != 201) {
          print('❌ Upload error response: ${response.body}');
          throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
        }
      } else {
        // For mobile: use Supabase Storage API with proper FileOptions
        await supabase.storage
            .from(_bucketName)
            .uploadBinary(
              storagePath,
              imageBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
      }

      print('✅ Receipt uploaded to Supabase Storage: $storagePath');
      
      // Return storage path (not public URL) for private bucket
      // Format: receipts/{userId}/{year}/{month}/{filename}
      return '$_bucketName/$storagePath';
    } catch (e) {
      print('❌ Failed to upload receipt: $e');
      rethrow;
    }
  }

  /// Generate a signed URL for viewing a receipt (expires in 1 hour)
  /// 
  /// [storagePath] - The storage path returned from uploadReceipt()
  /// Returns a temporary signed URL that expires after 1 hour
  static Future<String> getSignedUrl(String storagePath) async {
    try {
      // Remove bucket name prefix if present
      String path = storagePath;
      if (path.startsWith('$_bucketName/')) {
        path = path.substring(_bucketName.length + 1);
      }

      final signedUrl = await supabase.storage
          .from(_bucketName)
          .createSignedUrl(path, _signedUrlExpirySeconds);

      return signedUrl;
    } catch (e) {
      print('❌ Failed to generate signed URL: $e');
      rethrow;
    }
  }

  /// Delete receipt from Supabase Storage
  static Future<void> deleteReceipt(String storagePath) async {
    try {
      // Remove bucket name prefix if present
      String path = storagePath;
      if (path.startsWith('$_bucketName/')) {
        path = path.substring(_bucketName.length + 1);
      }

      // Delete from storage
      await supabase.storage
          .from(_bucketName)
          .remove([path]);
      
      print('✅ Receipt deleted from Supabase Storage: $path');
    } catch (e) {
      print('⚠️ Failed to delete receipt: $e');
      // Don't rethrow - receipt might already be deleted
    }
  }
}

