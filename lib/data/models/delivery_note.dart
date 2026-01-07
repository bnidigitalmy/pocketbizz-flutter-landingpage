import 'package:flutter/material.dart';

/// Delivery Note Model
/// Tracks multiple notes/updates for a delivery
class DeliveryNote {
  final String id;
  final String deliveryId;
  final String businessOwnerId;
  final String note;
  final String noteType; // general, internal, vendor_note, issue, resolution
  final String? addedByUserId;
  final String? addedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryNote({
    required this.id,
    required this.deliveryId,
    required this.businessOwnerId,
    required this.note,
    this.noteType = 'general',
    this.addedByUserId,
    this.addedByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeliveryNote.fromJson(Map<String, dynamic> json) {
    return DeliveryNote(
      id: json['id'] as String,
      deliveryId: json['delivery_id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      note: json['note'] as String,
      noteType: json['note_type'] as String? ?? 'general',
      addedByUserId: json['added_by_user_id'] as String?,
      addedByName: json['added_by_name'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'business_owner_id': businessOwnerId,
      'note': note,
      'note_type': noteType,
      'added_by_user_id': addedByUserId,
      'added_by_name': addedByName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get note type label in Malay
  String getNoteTypeLabel() {
    switch (noteType) {
      case 'general':
        return 'Umum';
      case 'internal':
        return 'Dalaman';
      case 'vendor_note':
        return 'Nota Vendor';
      case 'issue':
        return 'Isu';
      case 'resolution':
        return 'Penyelesaian';
      default:
        return noteType;
    }
  }

  /// Get note type color
  Color getNoteTypeColor() {
    switch (noteType) {
      case 'general':
        return Colors.blue;
      case 'internal':
        return Colors.grey;
      case 'vendor_note':
        return Colors.green;
      case 'issue':
        return Colors.red;
      case 'resolution':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}

