import '../../../../core/supabase/supabase_client.dart';
import '../models/google_drive_token.dart';

class GoogleDriveTokenRepositorySupabase {
  static const String _table = 'google_drive_tokens';

  /// Get stored token for current user
  Future<GoogleDriveToken?> getToken() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    try {
      final response = await supabase
          .from(_table)
          .select()
          .eq('business_owner_id', userId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return GoogleDriveToken.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error getting Google Drive token: $e');
      return null;
    }
  }

  /// Save or update token for current user
  Future<GoogleDriveToken> saveToken({
    required String accessToken,
    String? refreshToken,
    required DateTime tokenExpiry,
    String? googleEmail,
    String? googleUserId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final payload = {
      'business_owner_id': userId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_expiry': tokenExpiry.toIso8601String(),
      'google_email': googleEmail,
      'google_user_id': googleUserId,
    };

    try {
      // Try to update first
      final existing = await supabase
          .from(_table)
          .select()
          .eq('business_owner_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        final response = await supabase
            .from(_table)
            .update(payload)
            .eq('business_owner_id', userId)
            .select()
            .single();

        return GoogleDriveToken.fromJson(response as Map<String, dynamic>);
      } else {
        // Insert new
        final response = await supabase
            .from(_table)
            .insert(payload)
            .select()
            .single();

        return GoogleDriveToken.fromJson(response as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error saving Google Drive token: $e');
      rethrow;
    }
  }

  /// Delete token for current user (sign out)
  Future<void> deleteToken() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      await supabase
          .from(_table)
          .delete()
          .eq('business_owner_id', userId);
    } catch (e) {
      print('Error deleting Google Drive token: $e');
      // Don't rethrow - sign out should succeed even if delete fails
    }
  }
}

