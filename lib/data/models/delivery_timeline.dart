/// Delivery Timeline Event Model
/// Tracks all status changes and important events for a delivery
class DeliveryTimelineEvent {
  final String id;
  final String deliveryId;
  final String businessOwnerId;
  final String eventType; // created, status_changed, payment_status_changed, etc.
  final String? oldValue;
  final String? newValue;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String? changedByUserId;
  final String? changedByName;
  final DateTime createdAt;

  DeliveryTimelineEvent({
    required this.id,
    required this.deliveryId,
    required this.businessOwnerId,
    required this.eventType,
    this.oldValue,
    this.newValue,
    this.description,
    this.metadata,
    this.changedByUserId,
    this.changedByName,
    required this.createdAt,
  });

  factory DeliveryTimelineEvent.fromJson(Map<String, dynamic> json) {
    return DeliveryTimelineEvent(
      id: json['id'] as String,
      deliveryId: json['delivery_id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      eventType: json['event_type'] as String,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      changedByUserId: json['changed_by_user_id'] as String?,
      changedByName: json['changed_by_name'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'business_owner_id': businessOwnerId,
      'event_type': eventType,
      'old_value': oldValue,
      'new_value': newValue,
      'description': description,
      'metadata': metadata,
      'changed_by_user_id': changedByUserId,
      'changed_by_name': changedByName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get human-readable event label
  String getEventLabel() {
    switch (eventType) {
      case 'created':
        return 'Penghantaran Dibuat';
      case 'status_changed':
        return 'Status Diubah';
      case 'payment_status_changed':
        return 'Status Bayaran Diubah';
      case 'rejection_added':
        return 'Rejection Ditambah';
      case 'rejection_updated':
        return 'Rejection Dikemaskini';
      case 'invoice_generated':
        return 'Invois Dijana';
      case 'note_added':
        return 'Nota Ditambah';
      case 'item_added':
        return 'Item Ditambah';
      case 'item_updated':
        return 'Item Dikemaskini';
      case 'item_removed':
        return 'Item Dibuang';
      default:
        return eventType;
    }
  }

  /// Get status label in Malay
  static String getStatusLabel(String status) {
    switch (status) {
      case 'delivered':
        return 'Dihantar';
      case 'pending':
        return 'Menunggu';
      case 'claimed':
        return 'Dituntut';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  /// Get payment status label in Malay
  static String getPaymentStatusLabel(String? status) {
    if (status == null) return 'Tiada';
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'partial':
        return 'Separa';
      case 'settled':
        return 'Selesai';
      default:
        return status;
    }
  }
}

