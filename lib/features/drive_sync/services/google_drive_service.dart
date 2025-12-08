import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/auth.dart';
import '../../../core/config/app_config.dart';
import '../data/models/drive_sync_log.dart';
import '../data/repositories/drive_sync_repository_supabase.dart';
import '../data/repositories/google_drive_token_repository_supabase.dart';
import '../data/models/google_drive_token.dart';

/// Google Drive Service for syncing documents
/// 
/// This service handles:
/// - Google Sign-In authentication
/// - Uploading files to Google Drive
/// - Creating folders
/// - Logging sync operations
class GoogleDriveService {
  final DriveSyncRepositorySupabase _syncRepo = DriveSyncRepositorySupabase();
  final GoogleDriveTokenRepositorySupabase _tokenRepo = GoogleDriveTokenRepositorySupabase();
  
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
      // For web, we need to configure the hosted domain or leave it null
      // This helps avoid some cross-origin issues
      hostedDomain: null,
    );
    
    // Try to restore session from stored tokens
    await _restoreSessionFromStoredToken();
  }
  
  /// Restore session from stored token in Supabase
  Future<bool> _restoreSessionFromStoredToken() async {
    try {
      final token = await _tokenRepo.getToken();
      if (token == null) {
        print('📭 No stored token found');
        return false;
      }
      
      // Check if token is expired
      if (token.isExpired) {
        print('⏰ Stored token expired, need to refresh');
        // TODO: Implement token refresh if we have refresh_token
        await _tokenRepo.deleteToken();
        return false;
      }
      
      // Initialize Drive API with stored token
      // Note: RefreshToken might not be available in this version of googleapis_auth
      // For now, we'll use null and rely on re-authentication when token expires
      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', token.accessToken, token.tokenExpiry),
          null, // RefreshToken not available in current googleapis_auth version
          _scopes,
        ),
      );
      
      _driveApi = drive.DriveApi(client);
      print('✅ Session restored from stored token');
      print('📊 User: ${token.googleEmail ?? 'Unknown'}');
      return true;
    } catch (e) {
      print('❌ Failed to restore session: $e');
      return false;
    }
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
      // Note: AccessToken requires UTC DateTime for expiry
      // Google OAuth tokens typically expire in 1 hour
      final expiryTime = DateTime.now().toUtc().add(const Duration(hours: 1));
      
      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken, expiryTime),
          null, // refreshToken
          _scopes,
        ),
      );

      // Initialize Drive API
      _driveApi = drive.DriveApi(client);
      
      // Save token to Supabase for persistence
      try {
        await _tokenRepo.saveToken(
          accessToken: accessToken,
          refreshToken: null, // Google Sign-In on web doesn't provide refresh token
          tokenExpiry: expiryTime,
          googleEmail: account.email,
          googleUserId: account.id,
        );
        print('💾 Token saved to database');
      } catch (e) {
        print('⚠️ Failed to save token: $e');
        // Don't fail sign-in if token save fails
      }
      
      print('✅ Google Sign-In successful. Drive API initialized.');
      print('📊 Current user: ${account.email}');
      
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
    
    // Delete stored token
    try {
      await _tokenRepo.deleteToken();
      print('🗑️ Stored token deleted');
    } catch (e) {
      print('⚠️ Failed to delete token: $e');
    }
  }

  /// Check if user is signed in
  /// 
  /// On web, _googleSignIn?.currentUser might be null even after successful sign-in,
  /// so we primarily check _driveApi which is the most reliable indicator.
  /// If _driveApi is set, we're definitely signed in.
  bool get isSignedIn {
    // If Drive API is initialized, we're definitely signed in
    if (_driveApi != null) {
      return true;
    }
    
    // If Google Sign-In has a current user, we might be signed in but Drive API not initialized
    // This can happen on web after a page refresh or session restore
    if (_googleSignIn?.currentUser != null) {
      // We have a Google Sign-In user, but Drive API is not initialized
      // This is a valid signed-in state, but we need to re-initialize Drive API
      return false; // Return false so autoSyncDocument can re-initialize
    }
    
    return false;
  }
  
  /// Re-initialize Drive API from stored token
  /// This is the preferred method as it doesn't require Google Sign-In session
  Future<bool> _reinitializeDriveApi() async {
    // Try to restore from stored token first (more reliable)
    final restored = await _restoreSessionFromStoredToken();
    if (restored) {
      return true;
    }
    
    // Fallback: Try to get from Google Sign-In session
    try {
      GoogleSignInAccount? account;
      
      // First try to get current user
      account = _googleSignIn?.currentUser;
      
      // If currentUser is null (common on web), try silent sign-in
      if (account == null) {
        print('⚠️ currentUser is null, trying silent sign-in...');
        account = await _googleSignIn?.signInSilently();
      }
      
      if (account == null) {
        print('⚠️ Cannot re-initialize: No Google Sign-In user');
        return false;
      }
      
      final authHeaders = await account.authHeaders;
      final accessToken = authHeaders['Authorization']?.replaceFirst('Bearer ', '');
      
      if (accessToken == null) {
        print('⚠️ Cannot re-initialize: No access token');
        return false;
      }
      
      final expiryTime = DateTime.now().toUtc().add(const Duration(hours: 1));
      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken, expiryTime),
          null,
          _scopes,
        ),
      );
      
      _driveApi = drive.DriveApi(client);
      
      // Save token for future use
      try {
        await _tokenRepo.saveToken(
          accessToken: accessToken,
          refreshToken: null,
          tokenExpiry: expiryTime,
          googleEmail: account.email,
          googleUserId: account.id,
        );
      } catch (e) {
        print('⚠️ Failed to save token: $e');
      }
      
      print('✅ Drive API re-initialized successfully');
      return true;
    } catch (e) {
      print('❌ Failed to re-initialize Drive API: $e');
      return false;
    }
  }

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

      print('📤 Uploading file to Google Drive: $fileName');
      final uploaded = await _driveApi!.files.create(
        file,
        uploadMedia: media,
      );

      print('📥 Upload response received');
      print('   - ID: ${uploaded.id}');
      print('   - WebViewLink: ${uploaded.webViewLink}');
      print('   - Name: ${uploaded.name}');

      final fileId = uploaded.id;
      if (fileId == null || fileId.isEmpty) {
        throw Exception('Failed to upload file: No file ID returned');
      }

      // Get web view link
      final webViewLink = uploaded.webViewLink ?? 
          'https://drive.google.com/file/d/$fileId/view';

      // Ensure webViewLink is not null or empty
      if (webViewLink.isEmpty) {
        throw Exception('Failed to get web view link for uploaded file');
      }

      print('✅ File uploaded successfully: $fileId');

      // Log sync
      try {
        await _syncRepo.createSyncLog(
          fileName: fileName,
          fileType: fileType,
          driveFileId: fileId,
          driveWebViewLink: webViewLink,
          fileSizeBytes: fileData.length,
          mimeType: mimeType,
          driveFolderId: folderId,
          relatedEntityType: relatedEntityType,
          relatedEntityId: relatedEntityId,
          vendorName: vendorName,
          syncStatus: 'success',
        );
        print('✅ Sync log created successfully');
      } catch (e) {
        print('⚠️ Failed to create sync log: $e');
        // Don't throw - file was uploaded successfully, just logging failed
      }

      return {
        'fileId': fileId,
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
    // Ensure we're initialized
    if (_googleSignIn == null) {
      await initialize();
    }
    
    // Check sign-in status and re-initialize if needed
    if (!isSignedIn) {
      // Try to restore session if Drive API is not initialized
      // On web, _googleSignIn?.currentUser might be null even after successful sign-in,
      // so _reinitializeDriveApi will try signInSilently() to restore the session
      if (_driveApi == null) {
        print('⚠️ Drive API not initialized. Attempting to restore session...');
        final restored = await _reinitializeDriveApi();
        if (restored && isSignedIn) {
          print('✅ Session restored successfully');
        } else {
          print('⏭️ Cannot sync: User not signed in to Google Drive');
          return false;
        }
      } else {
        print('⏭️ Cannot sync: User not signed in to Google Drive');
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

    if (result != null) {
      print('✅ Successfully synced to Google Drive: $fileName');
      print('🔗 Drive link: ${result['webViewLink']}');
    } else {
      print('❌ Failed to sync to Google Drive: $fileName');
    }

    return result != null;
  }
}

