import 'dart:typed_data';
import '../services/google_drive_service.dart';

/// Helper class for Google Drive sync integration
/// Provides non-blocking sync functionality for document generation flows
class DriveSyncHelper {
  static GoogleDriveService? _driveService;

  /// Get or create Google Drive service instance
  static GoogleDriveService get _service {
    _driveService ??= GoogleDriveService();
    return _driveService!;
  }

  /// Initialize Google Drive service
  static Future<void> initialize() async {
    await _service.initialize();
  }

  /// Check if user is signed in to Google Drive
  static bool get isSignedIn => _service.isSignedIn;

  /// Sync PDF document to Google Drive (non-blocking, silent failure)
  /// 
  /// This method will:
  /// 1. Check if user is signed in, if not, skip sync (don't block)
  /// 2. Upload file to Google Drive
  /// 3. Log sync operation
  /// 
  /// Errors are caught and logged, but won't affect the main flow
  static Future<void> syncDocumentSilently({
    required Uint8List pdfData,
    required String fileName,
    required String fileType, // 'invoice', 'thermal_invoice', 'claim_statement', etc.
    String? relatedEntityType, // 'sale', 'claim', 'booking', 'delivery'
    String? relatedEntityId,
    String? vendorName,
  }) async {
    try {
      // Initialize if not already done
      await _service.initialize();
      
      // Check if user is signed in, if not, skip sync (don't block)
      if (!_service.isSignedIn) {
        // Try to sign in silently (don't show dialog if user hasn't signed in before)
        // If user hasn't signed in, just skip sync - don't block the flow
        final signedIn = await _service.signIn();
        if (!signedIn) {
          // User not signed in or cancelled - that's okay, just skip sync
          return;
        }
      }

      // Sync to Google Drive
      await _service.autoSyncDocument(
        pdfData: pdfData,
        fileName: fileName,
        fileType: fileType,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        vendorName: vendorName,
      );
    } catch (e) {
      // Silently handle errors - don't affect main flow
      // In production, you might want to log this to analytics
      print('Drive sync error (silent): $e');
    }
  }

  /// Sync document with user notification on success/failure
  /// Use this when you want to show feedback to user
  static Future<bool> syncDocumentWithFeedback({
    required Uint8List pdfData,
    required String fileName,
    required String fileType,
    String? relatedEntityType,
    String? relatedEntityId,
    String? vendorName,
  }) async {
    try {
      await _service.initialize();
      
      if (!_service.isSignedIn) {
        final signedIn = await _service.signIn();
        if (!signedIn) {
          return false; // User cancelled sign in
        }
      }

      await _service.autoSyncDocument(
        pdfData: pdfData,
        fileName: fileName,
        fileType: fileType,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        vendorName: vendorName,
      );

      return true;
    } catch (e) {
      print('Drive sync error: $e');
      return false;
    }
  }

  /// Sign in to Google Drive (with UI)
  static Future<bool> signIn() async {
    await _service.initialize();
    return await _service.signIn();
  }

  /// Sign out from Google Drive
  static Future<void> signOut() async {
    await _service.initialize();
    return await _service.signOut();
  }
}

