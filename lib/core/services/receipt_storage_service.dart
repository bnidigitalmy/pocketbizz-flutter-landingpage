import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../supabase/supabase_client.dart';

/// Service for handling receipt image uploads to Supabase Storage (PRIVATE bucket)
class ReceiptStorageService {
  static const String _bucketName = 'receipts';
  
  /// Default signed URL expiry duration (1 hour)
  static const int _signedUrlExpirySeconds = 3600;

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
        
        final encodedPath = Uri.encodeComponent(storagePath);
        final storageUrl = 'https://gxllowlurizrkvpdircw.supabase.co/storage/v1/object/$_bucketName/$encodedPath';
        
        // Upload using HTTP PUT
        final response = await http.put(
          Uri.parse(storageUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'image/jpeg',
            'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4bGxvd2x1cml6cmt2cGRpcmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMTAyMDksImV4cCI6MjA3OTc4NjIwOX0.Avft6LyKGwmU8JH3hXmO7ukNBlgG1XngjBX-prObycs',
            'x-upsert': 'true', // Allow overwrite
          },
          body: imageBytes,
        );
        
        if (response.statusCode != 200 && response.statusCode != 201) {
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

