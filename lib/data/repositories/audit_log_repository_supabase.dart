import '../../core/supabase/supabase_client.dart';
import '../models/audit_log.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Audit Log Repository
/// 
/// Handles audit logging for compliance and security tracking
class AuditLogRepositorySupabase {
  /// Get user's IP address (web only)
  String? _getUserIpAddress() {
    try {
      // For web, we can't directly get IP from client
      // This would need to be passed from server-side or tracked separately
      // For now, return null - can be enhanced later
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user agent (web only)
  String? _getUserAgent() {
    try {
      if (kIsWeb) {
        // For web, user agent would need to be passed from client-side
        // Can be enhanced with platform-specific implementation
        return 'Web Client';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Log an audit event
  /// 
  /// This is the main method to log any security-sensitive action
  Future<String> log({
    required AuditAction action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? details,
    String? ipAddress,
    String? userAgent,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated - cannot log audit event');
    }

    try {
      // Use the database function for secure insertion
      final response = await supabase.rpc(
        'insert_audit_log',
        params: {
          'p_user_id': userId,
          'p_action': action.value,
          'p_entity_type': entityType,
          'p_entity_id': entityId,
          'p_details': details,
          'p_ip_address': ipAddress ?? _getUserIpAddress(),
          'p_user_agent': userAgent ?? _getUserAgent(),
        },
      );

      return response as String;
    } catch (e) {
      // Don't throw - audit logging failure shouldn't break the app
      // But log to console for debugging
      print('⚠️ Failed to log audit event: $e');
      return '';
    }
  }

  /// Get audit logs for current user
  Future<List<AuditLog>> getMyLogs({
    AuditAction? action,
    String? entityType,
    int limit = 100,
    int offset = 0,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    var query = supabase
        .from('audit_logs')
        .select()
        .eq('business_owner_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (action != null) {
      query = query.eq('action', action.value);
    }

    if (entityType != null) {
      query = query.eq('entity_type', entityType);
    }

    final response = await query;
    return (response as List)
        .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Log login event
  Future<void> logLogin({Map<String, dynamic>? details}) async {
    await log(
      action: AuditAction.login,
      entityType: 'user',
      entityId: supabase.auth.currentUser?.id,
      details: details,
    );
  }

  /// Log logout event
  Future<void> logLogout() async {
    await log(
      action: AuditAction.logout,
      entityType: 'user',
      entityId: supabase.auth.currentUser?.id,
    );
  }

  /// Log delete event
  Future<void> logDelete({
    required String entityType,
    required String entityId,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: AuditAction.delete,
      entityType: entityType,
      entityId: entityId,
      details: details,
    );
  }

  /// Log export event
  Future<void> logExport({
    required String entityType,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: AuditAction.export,
      entityType: entityType,
      details: details,
    );
  }

  /// Log payment event
  Future<void> logPayment({
    required String entityType,
    required String entityId,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: AuditAction.payment,
      entityType: entityType,
      entityId: entityId,
      details: details,
    );
  }

  /// Log create event
  Future<void> logCreate({
    required String entityType,
    required String entityId,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: AuditAction.create,
      entityType: entityType,
      entityId: entityId,
      details: details,
    );
  }

  /// Log update event
  Future<void> logUpdate({
    required String entityType,
    required String entityId,
    Map<String, dynamic>? details,
  }) async {
    await log(
      action: AuditAction.update,
      entityType: entityType,
      entityId: entityId,
      details: details,
    );
  }
}

