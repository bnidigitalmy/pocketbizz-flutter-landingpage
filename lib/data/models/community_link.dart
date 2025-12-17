import 'package:flutter/material.dart';

/// Community Link Model
/// Represents community links (Facebook, Telegram, etc.)
class CommunityLink {
  final String id;
  final String businessOwnerId;
  
  // Link details
  final String platform; // 'facebook', 'telegram', 'whatsapp', 'discord', 'other'
  final String name;
  final String url;
  final String? description;
  final String? icon;
  
  // Display
  final int displayOrder;
  final bool isActive;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  CommunityLink({
    required this.id,
    required this.businessOwnerId,
    required this.platform,
    required this.name,
    required this.url,
    this.description,
    this.icon,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityLink.fromJson(Map<String, dynamic> json) {
    return CommunityLink(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      platform: json['platform'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'platform': platform,
      'name': name,
      'url': url,
      'description': description,
      'icon': icon,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  String get platformLabel {
    switch (platform) {
      case 'facebook':
        return 'Facebook';
      case 'telegram':
        return 'Telegram';
      case 'whatsapp':
        return 'WhatsApp';
      case 'discord':
        return 'Discord';
      case 'other':
        return 'Lain-lain';
      default:
        return platform;
    }
  }

  IconData get platformIcon {
    switch (platform) {
      case 'facebook':
        return Icons.facebook;
      case 'telegram':
        return Icons.telegram;
      case 'whatsapp':
        return Icons.chat; // WhatsApp icon not available, use chat
      case 'discord':
        return Icons.forum; // Discord icon not available, use forum
      default:
        return Icons.link;
    }
  }
}

