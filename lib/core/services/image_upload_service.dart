import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../supabase/supabase_client.dart';

/// Service for handling image uploads to Supabase Storage
class ImageUploadService {
  // Bucket name: product-images (lowercase) - matches Supabase Dashboard and policies
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

      // Read bytes from XFile (works for both web and mobile)
      final Uint8List fileBytes = await imageFile.readAsBytes();
      
      // Use Supabase SDK uploadBinary for both web and mobile (more reliable)
      await supabase.storage
          .from(_bucketName)
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      
      // Small delay to ensure file is fully committed to storage
      // This helps prevent 400 errors when immediately trying to retrieve the image
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get public URL
      final String publicUrl = supabase.storage
          .from(_bucketName)
          .getPublicUrl(filePath);
      
      // Log for debugging
      print('✅ Upload successful');
      print('   Storage path: $filePath');
      print('   Public URL: $publicUrl');
      
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

      // Read bytes from XFile (works for both web and mobile)
      final Uint8List fileBytes = await imageFile.readAsBytes();
      
      // Use Supabase SDK uploadBinary for both web and mobile (more reliable)
      await supabase.storage
          .from(_bucketName)
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      
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

