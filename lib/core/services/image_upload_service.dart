import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../supabase/supabase_client.dart';

// Conditional import for File - only import dart:io when NOT on web
// On web, we use a stub that provides a minimal File interface
import 'dart:io' if (dart.library.html) 'io_stub.dart' show File;

/// Service for handling image uploads to Supabase Storage
class ImageUploadService {
  static const String _bucketName = 'product-images';
  final ImagePicker _picker = ImagePicker();

  XFile _xFileFromPickedBytes(PlatformFile f) {
    final bytes = f.bytes;
    if (bytes == null) {
      throw Exception('Fail gambar tidak dapat dibaca');
    }
    final ext = (f.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    return XFile.fromData(
      bytes,
      name: f.name,
      mimeType: mime,
    );
  }

  /// Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      // Web (especially iOS Safari/PWA): avoid ImagePicker blob: URLs that can get revoked.
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        return _xFileFromPickedBytes(result.files.single);
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      // Web: use FilePicker too. Most browsers will still allow camera capture via file input.
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        return _xFileFromPickedBytes(result.files.single);
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to take photo: $e');
    }
  }

  /// Upload image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadProductImage(XFile imageFile, String productId) async {
    try {
      // Generate unique file name
      final String fileName = '$productId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'products/$fileName';

      // Handle platform-specific file upload
      if (kIsWeb) {
        // For web: read bytes from XFile
        final Uint8List fileBytes = await imageFile.readAsBytes();
        
        // Check authentication
        final accessToken = supabase.auth.currentSession?.accessToken;
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('User not authenticated. Please login first.');
        }
        
        // For web, use HTTP PUT with proper headers
        // Supabase Storage API endpoint
        final encodedPath = Uri.encodeComponent(filePath);
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
            'Content-Type': 'image/jpeg',
            'apikey': supabaseAnonKey,
            'x-upsert': 'false',
          },
          body: fileBytes,
        );
        
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
        }
      } else {
        // For mobile: use File from dart:io
        final File file = File(imageFile.path);
        
        // Upload to Supabase Storage
        await supabase.storage
            .from(_bucketName)
            .upload(
              filePath,
              file,
            );
      }

      // Get public URL
      final String publicUrl = supabase.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete image from Supabase Storage
  Future<void> deleteProductImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the index of the bucket name
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        throw Exception('Invalid image URL format');
      }
      
      // Get the file path after the bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Delete from storage
      await supabase.storage
          .from(_bucketName)
          .remove([filePath]);
    } catch (e) {
      // Log error but don't throw - image might already be deleted
      // Image might already be deleted, so we ignore the error
    }
  }

  /// Update product image (delete old, upload new)
  Future<String> updateProductImage(
    XFile newImageFile,
    String productId,
    String? oldImageUrl,
  ) async {
    // Delete old image if exists
    if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
      try {
        await deleteProductImage(oldImageUrl);
      } catch (e) {
        // Old image might already be deleted, so we ignore the error
      }
    }

    // Upload new image
    return await uploadProductImage(newImageFile, productId);
  }

  /// Upload QR Code image to Supabase Storage
  /// Returns the public URL of the uploaded QR code
  Future<String> uploadQrCodeImage(XFile imageFile, String userId) async {
    try {
      // Generate unique file name
      final String fileName = 'qr-code-${userId}-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = 'business-assets/$fileName';

      // Handle platform-specific file upload
      if (kIsWeb) {
        // For web: read bytes from XFile
        final Uint8List fileBytes = await imageFile.readAsBytes();
        
        // Check authentication
        final accessToken = supabase.auth.currentSession?.accessToken;
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('User not authenticated. Please login first.');
        }
        
        // Get Supabase URL from environment
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
        
        final encodedPath = Uri.encodeComponent(filePath);
        // Use product-images bucket for business assets (QR codes)
        final storageUrl = '$supabaseUrl/storage/v1/object/product-images/$encodedPath';
        
        // Upload using HTTP PUT
        final response = await http.put(
          Uri.parse(storageUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'image/jpeg',
            'apikey': supabaseAnonKey,
            'x-upsert': 'false',
          },
          body: fileBytes,
        );
        
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
        }
      } else {
        // For mobile: use File from dart:io
        final File file = File(imageFile.path);
        
        // Upload to Supabase Storage
        await supabase.storage
            .from(_bucketName)
            .upload(
              filePath,
              file,
            );
      }

      // Get public URL
      final String publicUrl = supabase.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload QR code: $e');
    }
  }
}

