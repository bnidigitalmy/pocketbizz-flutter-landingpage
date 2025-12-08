import '../../../../core/supabase/supabase_client.dart';
import '../models/drive_sync_log.dart';

class DriveSyncRepositorySupabase {
  static const String _table = 'google_drive_sync_logs';

  /// Get all sync logs for current user
  Future<List<DriveSyncLog>> getSyncLogs() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await supabase
        .from(_table)
        .select()
        .eq('business_owner_id', userId)
        .order('synced_at', ascending: false);

    final data = (response as List).cast<Map<String, dynamic>>();
    return data.map((json) => DriveSyncLog.fromJson(json)).toList();
  }

  /// Create a new sync log entry
  Future<DriveSyncLog> createSyncLog({
    required String fileName,
    required String fileType,
    required String driveFileId,
    required String driveWebViewLink,
    int? fileSizeBytes,
    String? mimeType,
    String? driveFolderId,
    String? relatedEntityType,
    String? relatedEntityId,
    String? vendorName,
    String syncStatus = 'success',
    String? errorMessage,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final payload = {
      'business_owner_id': userId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'drive_file_id': driveFileId,
      'drive_web_view_link': driveWebViewLink,
      'drive_folder_id': driveFolderId,
      'related_entity_type': relatedEntityType,
      'related_entity_id': relatedEntityId,
      'vendor_name': vendorName,
      'sync_status': syncStatus,
      'error_message': errorMessage,
    };

    try {
      final response = await supabase
          .from(_table)
          .insert(payload)
          .select()
          .single();

      if (response == null) {
        throw Exception('Failed to create sync log: No response from database');
      }

      return DriveSyncLog.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error creating sync log: $e');
      print('Payload: $payload');
      rethrow;
    }
  }

  /// Update sync log status
  Future<void> updateSyncLogStatus({
    required String id,
    required String syncStatus,
    String? errorMessage,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final payload = {
      'sync_status': syncStatus,
      if (errorMessage != null) 'error_message': errorMessage,
    };

    await supabase
        .from(_table)
        .update(payload)
        .eq('id', id)
        .eq('business_owner_id', userId);
  }

  /// Delete sync log
  Future<void> deleteSyncLog(String id) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await supabase
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('business_owner_id', userId);
  }
}

