import 'package:intl/intl.dart';
import 'announcement_media.dart';

/// Feedback Request Model
/// Represents user feedback, bug reports, feature requests, and suggestions
class FeedbackRequest {
  final String id;
  final String businessOwnerId;
  
  // Feedback details
  final String type; // 'bug', 'feature', 'suggestion', 'other'
  final String title;
  final String description;
  final String priority; // 'low', 'normal', 'high', 'urgent'
  
  // Status tracking
  final String status; // 'pending', 'reviewing', 'in_progress', 'completed', 'rejected', 'on_hold'
  
  // Admin response
  final String? adminNotes;
  final String? adminId;
  
  // Implementation tracking
  final String? implementationNotes;
  final DateTime? completedAt;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  // Attachments (image/video/file)
  final List<AnnouncementMedia> attachments;

  FeedbackRequest({
    required this.id,
    required this.businessOwnerId,
    required this.type,
    required this.title,
    required this.description,
    this.priority = 'normal',
    this.status = 'pending',
    this.adminNotes,
    this.adminId,
    this.implementationNotes,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
  });

  factory FeedbackRequest.fromJson(Map<String, dynamic> json) {
    List<AnnouncementMedia> attachments = [];
    final raw = json['attachments'];
    if (raw is List) {
      attachments = raw
          .whereType<Map<String, dynamic>>()
          .map(AnnouncementMedia.fromJson)
          .toList();
    }
    return FeedbackRequest(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'pending',
      adminNotes: json['admin_notes'] as String?,
      adminId: json['admin_id'] as String?,
      implementationNotes: json['implementation_notes'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      attachments: attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'type': type,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'admin_notes': adminNotes,
      'admin_id': adminId,
      'implementation_notes': implementationNotes,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'business_owner_id': businessOwnerId,
      'type': type,
      'title': title,
      'description': description,
      'priority': priority,
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  // Helper getters
  String get typeLabel {
    switch (type) {
      case 'bug':
        return 'Bug Report';
      case 'feature':
        return 'Feature Request';
      case 'suggestion':
        return 'Cadangan';
      case 'other':
        return 'Lain-lain';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'reviewing':
        return 'Dalam Semakan';
      case 'in_progress':
        return 'Sedang Dibangunkan';
      case 'completed':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      case 'on_hold':
        return 'Ditangguhkan';
      default:
        return status;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 'low':
        return 'Rendah';
      case 'normal':
        return 'Biasa';
      case 'high':
        return 'Tinggi';
      case 'urgent':
        return 'Mendesak';
      default:
        return priority;
    }
  }
}

