/// Audit Log Model
/// 
/// Represents a single audit log entry for compliance and security tracking
class AuditLog {
  final String id;
  final String userId;
  final String businessOwnerId;
  final AuditAction action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final String? userAgent;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    required this.userId,
    required this.businessOwnerId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.details,
    this.ipAddress,
    this.userAgent,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      action: AuditAction.fromString(json['action'] as String),
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_owner_id': businessOwnerId,
      'action': action.value,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Audit Action Types
enum AuditAction {
  login,
  logout,
  create,
  update,
  delete,
  export,
  payment,
  passwordReset,
  emailVerification,
  exportData;

  String get value {
    switch (this) {
      case AuditAction.login:
        return 'login';
      case AuditAction.logout:
        return 'logout';
      case AuditAction.create:
        return 'create';
      case AuditAction.update:
        return 'update';
      case AuditAction.delete:
        return 'delete';
      case AuditAction.export:
        return 'export';
      case AuditAction.payment:
        return 'payment';
      case AuditAction.passwordReset:
        return 'password_reset';
      case AuditAction.emailVerification:
        return 'email_verification';
      case AuditAction.exportData:
        return 'export_data';
    }
  }

  static AuditAction fromString(String value) {
    switch (value) {
      case 'login':
        return AuditAction.login;
      case 'logout':
        return AuditAction.logout;
      case 'create':
        return AuditAction.create;
      case 'update':
        return AuditAction.update;
      case 'delete':
        return AuditAction.delete;
      case 'export':
        return AuditAction.export;
      case 'payment':
        return AuditAction.payment;
      case 'password_reset':
        return AuditAction.passwordReset;
      case 'email_verification':
        return AuditAction.emailVerification;
      case 'export_data':
        return AuditAction.exportData;
      default:
        throw ArgumentError('Unknown audit action: $value');
    }
  }
}

