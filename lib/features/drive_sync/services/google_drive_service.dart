import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import '../../../core/config/app_config.dart';
import '../data/models/drive_sync_log.dart';
import '../data/repositories/drive_sync_repository_supabase.dart';

/// Google Drive Service for syncing documents
/// 
/// This service handles:
/// - Google Sign-In authentication
/// - Uploading files to Google Drive
/// - Creating folders
/// - Logging sync operations
class GoogleDriveService {
  final DriveSyncRepositorySupabase _syncRepo = DriveSyncRepositorySupabase();
  
  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  
  // Google Sign-In configuration
  // Note: You need to configure OAuth 2.0 credentials in Google Cloud Console
  // and add the client ID to your app configuration
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.file', // Read/write access to files created by the app
  ];

  /// Initialize Google Sign-In
  Future<void> initialize() async {
    _googleSignIn = GoogleSignIn(
      scopes: _scopes,
      clientId: AppConfig.googleOAuthClientId, // Required for Flutter Web
    );
  }

  /// Sign in to Google
  Future<bool> signIn() async {
    try {
      if (_googleSignIn == null) {
        await initialize();
      }
      
      final account = await _googleSignIn!.signIn();
      if (account == null) {
        return false; // User cancelled
      }

      // Get authentication headers
      final authHeaders = await account.authHeaders;
      final accessToken = authHeaders['Authorization']?.replaceFirst('Bearer ', '');
      
      if (accessToken == null) {
        return false;
      }

      // Create authenticated HTTP client
      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken, DateTime.now().add(const Duration(hours: 1))),
          null, // refreshToken
          _scopes,
        ),
      );

      // Initialize Drive API
      _driveApi = drive.DriveApi(client);
      
      return true;
    } catch (e) {
      print('Google Sign-In error: $e');
      return false;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    _driveApi = null;
  }

  /// Check if user is signed in
  bool get isSignedIn => _googleSignIn?.currentUser != null && _driveApi != null;

  /// Get or create a folder in Google Drive
  /// Returns the folder ID
  Future<String?> getOrCreateFolder(String folderName) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Google Drive');
    }

    try {
      // Search for existing folder
      final response = await _driveApi!.files.list(
        q: "name='$folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
      );

      if (response.files != null && response.files!.isNotEmpty) {
        return response.files!.first.id;
      }

      // Create new folder
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final created = await _driveApi!.files.create(folder);
      return created.id;
    } catch (e) {
      print('Error creating/getting folder: $e');
      return null;
    }
  }

  /// Upload a file to Google Drive
  /// 
  /// [fileData] - The file bytes
  /// [fileName] - Name of the file
  /// [mimeType] - MIME type (e.g., 'application/pdf')
  /// [folderId] - Optional folder ID to upload to
  /// [fileType] - Type identifier for logging (e.g., 'invoice', 'claim_statement')
  /// [relatedEntityType] - Type of related entity (e.g., 'sale', 'claim')
  /// [relatedEntityId] - ID of related entity
  /// [vendorName] - Optional vendor name for claims
  /// 
  /// Returns the Drive file ID and web view link
  Future<Map<String, String>?> uploadFile({
    required Uint8List fileData,
    required String fileName,
    required String mimeType,
    String? folderId,
    required String fileType,
    String? relatedEntityType,
    String? relatedEntityId,
    String? vendorName,
  }) async {
    if (_driveApi == null) {
      throw Exception('Not signed in to Google Drive');
    }

    try {
      // Create file metadata
      final file = drive.File()
        ..name = fileName
        ..mimeType = mimeType;

      // Add to folder if specified
      if (folderId != null) {
        file.parents = [folderId];
      }

      // Upload file
      final media = drive.Media(
        Stream.value(fileData),
        fileData.length,
        contentType: mimeType,
      );

      final uploaded = await _driveApi!.files.create(
        file,
        uploadMedia: media,
      );

      if (uploaded.id == null) {
        throw Exception('Failed to upload file');
      }

      // Get web view link
      final webViewLink = uploaded.webViewLink ?? 
          'https://drive.google.com/file/d/${uploaded.id}/view';

      // Log sync
      await _syncRepo.createSyncLog(
        fileName: fileName,
        fileType: fileType,
        driveFileId: uploaded.id!,
        driveWebViewLink: webViewLink,
        fileSizeBytes: fileData.length,
        mimeType: mimeType,
        driveFolderId: folderId,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        vendorName: vendorName,
        syncStatus: 'success',
      );

      return {
        'fileId': uploaded.id!,
        'webViewLink': webViewLink,
      };
    } catch (e) {
      // Log failed sync
      await _syncRepo.createSyncLog(
        fileName: fileName,
        fileType: fileType,
        driveFileId: 'failed',
        driveWebViewLink: '',
        fileSizeBytes: fileData.length,
        mimeType: mimeType,
        driveFolderId: folderId,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        vendorName: vendorName,
        syncStatus: 'failed',
        errorMessage: e.toString(),
      );

      print('Error uploading to Google Drive: $e');
      return null;
    }
  }

  /// Auto-sync a PDF document
  /// This is a convenience method that handles common document types
  Future<bool> autoSyncDocument({
    required Uint8List pdfData,
    required String fileName,
    required String fileType, // 'invoice', 'thermal_invoice', 'claim_statement', etc.
    String? relatedEntityType,
    String? relatedEntityId,
    String? vendorName,
  }) async {
    if (!isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) {
        return false;
      }
    }

    // Determine folder based on file type
    String? folderId;
    if (fileType.contains('invoice')) {
      folderId = await getOrCreateFolder('Invoices');
    } else if (fileType.contains('claim')) {
      folderId = await getOrCreateFolder('Claims');
    } else if (fileType.contains('receipt')) {
      folderId = await getOrCreateFolder('Receipts');
    }

    final result = await uploadFile(
      fileData: pdfData,
      fileName: fileName,
      mimeType: 'application/pdf',
      folderId: folderId,
      fileType: fileType,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      vendorName: vendorName,
    );

    return result != null;
  }
}

