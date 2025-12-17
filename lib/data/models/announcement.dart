import 'package:intl/intl.dart';

/// Announcement Model
/// Represents broadcast messages to all users
class Announcement {
  final String id;
  
  // Announcement details
  final String title;
  final String message;
  final String type; // 'info', 'success', 'warning', 'error', 'feature', 'maintenance'
  final String priority; // 'low', 'normal', 'high', 'urgent'
  
  // Targeting
  final String targetAudience; // 'all', 'trial', 'active', 'expired', 'grace'
  
  // Display settings
  final bool isActive;
  final DateTime? showUntil;
  final String? actionUrl;
  final String? actionLabel;
  
  // Metadata
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Computed
  final bool? isViewed; // Whether current user has viewed this

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.priority = 'normal',
    this.targetAudience = 'all',
    this.isActive = true,
    this.showUntil,
    this.actionUrl,
    this.actionLabel,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isViewed,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String? ?? 'info',
      priority: json['priority'] as String? ?? 'normal',
      targetAudience: json['target_audience'] as String? ?? 'all',
      isActive: json['is_active'] as bool? ?? true,
      showUntil: json['show_until'] != null
          ? DateTime.parse(json['show_until'] as String)
          : null,
      actionUrl: json['action_url'] as String?,
      actionLabel: json['action_label'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isViewed: json['is_viewed'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'target_audience': targetAudience,
      'is_active': isActive,
      'show_until': showUntil?.toIso8601String(),
      'action_url': actionUrl,
      'action_label': actionLabel,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_viewed': isViewed,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'target_audience': targetAudience,
      'is_active': isActive,
      'show_until': showUntil?.toIso8601String(),
      'action_url': actionUrl,
      'action_label': actionLabel,
    };
  }

  // Helper getters
  String get typeLabel {
    switch (type) {
      case 'info':
        return 'Maklumat';
      case 'success':
        return 'Berjaya';
      case 'warning':
        return 'Amaran';
      case 'error':
        return 'Ralat';
      case 'feature':
        return 'Ciri Baru';
      case 'maintenance':
        return 'Penyelenggaraan';
      default:
        return type;
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

  String get targetAudienceLabel {
    switch (targetAudience) {
      case 'all':
        return 'Semua Users';
      case 'trial':
        return 'Trial Users';
      case 'active':
        return 'Active Subscribers';
      case 'expired':
        return 'Expired Subscriptions';
      case 'grace':
        return 'Grace Period';
      default:
        return targetAudience;
    }
  }

  bool get isExpired {
    if (showUntil == null) return false;
    return DateTime.now().isAfter(showUntil!);
  }

  bool get shouldShow {
    return isActive && !isExpired;
  }
}

