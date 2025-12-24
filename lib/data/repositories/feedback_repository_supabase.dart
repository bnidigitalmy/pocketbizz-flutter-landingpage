import '../../core/supabase/supabase_client.dart';
import '../models/feedback_request.dart';

/// Feedback Repository for managing feedback requests
class FeedbackRepositorySupabase {
  /// Get all feedback for current user
  Future<List<FeedbackRequest>> getMyFeedback() async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('feedback_requests')
        .select()
        .eq('business_owner_id', userId)
        .order('created_at', ascending: false);

    final data = (response as List).cast<Map<String, dynamic>>();
    return data.map(FeedbackRequest.fromJson).toList();
  }

  /// Get all feedback (admin only) with pagination
  Future<List<FeedbackRequest>> getAllFeedback({
    String? status,
    String? type,
    int limit = 100,
    int offset = 0,
  }) async {
    var query = supabase.from('feedback_requests').select();

    if (status != null) {
      query = query.eq('status', status);
    }
    if (type != null) {
      query = query.eq('type', type);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1); // Add pagination
    final data = (response as List).cast<Map<String, dynamic>>();
    return data.map(FeedbackRequest.fromJson).toList();
  }

  /// Create new feedback request
  Future<FeedbackRequest> createFeedback({
    required String type,
    required String title,
    required String description,
    String priority = 'normal',
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final payload = {
      'business_owner_id': userId,
      'type': type,
      'title': title,
      'description': description,
      'priority': priority,
    };

    final response = await supabase
        .from('feedback_requests')
        .insert(payload)
        .select()
        .single();

    return FeedbackRequest.fromJson(response as Map<String, dynamic>);
  }

  /// Update feedback status (admin only)
  Future<FeedbackRequest> updateFeedbackStatus({
    required String id,
    required String status,
    String? adminNotes,
    String? implementationNotes,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    final updateData = <String, dynamic>{
      'status': status,
      'admin_id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (adminNotes != null) {
      updateData['admin_notes'] = adminNotes;
    }
    if (implementationNotes != null) {
      updateData['implementation_notes'] = implementationNotes;
    }
    if (status == 'completed') {
      updateData['completed_at'] = DateTime.now().toIso8601String();
    }

    final response = await supabase
        .from('feedback_requests')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

    final feedback = FeedbackRequest.fromJson(response as Map<String, dynamic>);

    // Send notification to user
    await _sendNotificationToUser(feedback);

    return feedback;
  }

  /// Send notification to user when feedback status is updated
  Future<void> _sendNotificationToUser(FeedbackRequest feedback) async {
    try {
      // Use insert_notification_log function to insert notification for another user
      // This function has SECURITY DEFINER to bypass RLS for system notifications
      await supabase.rpc('insert_notification_log', params: {
        'p_user_id': feedback.businessOwnerId,
        'p_channel': 'in_app',
        'p_type': 'feedback_status_update',
        'p_status': 'sent',
        'p_subject': 'Status Feedback Anda Telah Dikemaskini',
        'p_payload': {
          'feedback_id': feedback.id,
          'feedback_title': feedback.title,
          'status': feedback.status,
          'status_label': feedback.statusLabel,
          'admin_notes': feedback.adminNotes,
          'implementation_notes': feedback.implementationNotes,
        },
      });
    } catch (e) {
      // Log error but don't fail the update
      print('Error sending notification: $e');
    }
  }

  /// Get feedback statistics (admin only)
  Future<Map<String, dynamic>> getFeedbackStats() async {
    final allFeedback = await getAllFeedback();

    return {
      'total': allFeedback.length,
      'pending': allFeedback.where((f) => f.status == 'pending').length,
      'reviewing': allFeedback.where((f) => f.status == 'reviewing').length,
      'in_progress': allFeedback.where((f) => f.status == 'in_progress').length,
      'completed': allFeedback.where((f) => f.status == 'completed').length,
      'rejected': allFeedback.where((f) => f.status == 'rejected').length,
      'on_hold': allFeedback.where((f) => f.status == 'on_hold').length,
      'bugs': allFeedback.where((f) => f.type == 'bug').length,
      'features': allFeedback.where((f) => f.type == 'feature').length,
      'suggestions': allFeedback.where((f) => f.type == 'suggestion').length,
    };
  }
}

