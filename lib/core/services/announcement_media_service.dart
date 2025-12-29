import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../supabase/supabase_client.dart';
import '../../data/models/announcement_media.dart';

// Conditional import for File
import 'dart:io' if (dart.library.html) 'io_stub.dart' show File;

/// Service for handling announcement media uploads to Supabase Storage
class AnnouncementMediaService {
  static const String _bucketName = 'announcement-media';
  final ImagePicker _imagePicker = ImagePicker();

  String _normalizePrefix(String prefix) {
    if (prefix.isEmpty) return '';
    return prefix.endsWith('/') ? prefix : '$prefix/';
  }

  /// Pick image from gallery or camera
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      return image;
    } catch (e) {
      throw Exception('Gagal memilih gambar: $e');
    }
  }

  /// Pick video from gallery
  Future<XFile?> pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // Max 5 minutes
      );
      return video;
    } catch (e) {
      throw Exception('Gagal memilih video: $e');
    }
  }

  /// Pick file (PDF, DOC, etc.)
  Future<FilePickerResult?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      return result;
    } catch (e) {
      throw Exception('Gagal memilih fail: $e');
    }
  }

  /// Upload image and return AnnouncementMedia
  Future<AnnouncementMedia> uploadImage(
    XFile imageFile,
    String announcementId, {
    String folderPrefix = '',
  }) async {
    try {
      final String fileName = '${announcementId}-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '${_normalizePrefix(folderPrefix)}images/$fileName';

      final String url = await _uploadFile(
        file: imageFile,
        filePath: filePath,
        contentType: 'image/jpeg',
      );

      return AnnouncementMedia(
        type: 'image',
        url: url,
        filename: imageFile.name,
        size: await imageFile.length(),
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      throw Exception('Gagal upload gambar: $e');
    }
  }

  /// Upload video and return AnnouncementMedia
  Future<AnnouncementMedia> uploadVideo(
    XFile videoFile,
    String announcementId, {
    String folderPrefix = '',
  }) async {
    try {
      final String extension = videoFile.path.split('.').last;
      final String fileName = '${announcementId}-${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String filePath = '${_normalizePrefix(folderPrefix)}videos/$fileName';

      final String url = await _uploadFile(
        file: videoFile,
        filePath: filePath,
        contentType: 'video/$extension',
      );

      return AnnouncementMedia(
        type: 'video',
        url: url,
        filename: videoFile.name,
        size: await videoFile.length(),
        mimeType: 'video/$extension',
      );
    } catch (e) {
      throw Exception('Gagal upload video: $e');
    }
  }

  /// Upload file and return AnnouncementMedia
  Future<AnnouncementMedia> uploadFile(
    PlatformFile platformFile,
    String announcementId, {
    String folderPrefix = '',
  }
  ) async {
    try {
      final String extension = platformFile.extension ?? 'bin';
      final String fileName = '${announcementId}-${DateTime.now().millisecondsSinceEpoch}.$extension';
      final String filePath = '${_normalizePrefix(folderPrefix)}files/$fileName';

      String url;
      if (kIsWeb) {
        // For web, use bytes (path is not available on web)
        if (platformFile.bytes == null) {
          throw Exception('File bytes tidak tersedia');
        }
        url = await _uploadBytes(
          bytes: platformFile.bytes!,
          filePath: filePath,
          contentType: platformFile.extension != null
              ? _getMimeType(platformFile.extension!)
              : 'application/octet-stream',
        );
      } else {
        // For mobile, use file path
        if (platformFile.path == null) {
          throw Exception('File path tidak tersedia');
        }
        final file = File(platformFile.path!);
        url = await _uploadFileFromPath(
          file: file,
          filePath: filePath,
          contentType: platformFile.extension != null
              ? _getMimeType(platformFile.extension!)
              : 'application/octet-stream',
        );
      }

      return AnnouncementMedia(
        type: 'file',
        url: url,
        filename: platformFile.name,
        size: platformFile.size,
        mimeType: platformFile.extension != null
            ? _getMimeType(platformFile.extension!)
            : 'application/octet-stream',
      );
    } catch (e) {
      throw Exception('Gagal upload fail: $e');
    }
  }

  /// Internal method to upload file (XFile)
  Future<String> _uploadFile({
    required XFile file,
    required String filePath,
    required String contentType,
  }) async {
    if (kIsWeb) {
      final Uint8List fileBytes = await file.readAsBytes();
      return await _uploadBytes(
        bytes: fileBytes,
        filePath: filePath,
        contentType: contentType,
      );
    } else {
      final File fileObj = File(file.path);
      return await _uploadFileFromPath(
        file: fileObj,
        filePath: filePath,
        contentType: contentType,
      );
    }
  }

  /// Upload bytes (for web)
  Future<String> _uploadBytes({
    required Uint8List bytes,
    required String filePath,
    required String contentType,
  }) async {
    final accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('User tidak authenticated. Sila login dahulu.');
    }

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

    final response = await http.put(
      Uri.parse(storageUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': contentType,
        'apikey': supabaseAnonKey,
        'x-upsert': 'false',
      },
      body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload gagal: ${response.statusCode} - ${response.body}');
    }

    return supabase.storage.from(_bucketName).getPublicUrl(filePath);
  }

  /// Upload file from path (for mobile)
  Future<String> _uploadFileFromPath({
    required File file,
    required String filePath,
    required String contentType,
  }) async {
    await supabase.storage.from(_bucketName).upload(filePath, file);
    return supabase.storage.from(_bucketName).getPublicUrl(filePath);
  }

  /// Get MIME type from extension
  String _getMimeType(String extension) {
    final mimeTypes = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
    };
    return mimeTypes[extension.toLowerCase()] ?? 'application/octet-stream';
  }

  /// Delete media from storage
  Future<void> deleteMedia(String url) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        throw Exception('Invalid media URL format');
      }

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      await supabase.storage.from(_bucketName).remove([filePath]);
    } catch (e) {
      // Ignore errors - file might already be deleted
      print('Error deleting media: $e');
    }
  }
}
