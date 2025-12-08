class DriveSyncLog {
  final String id;
  final String businessOwnerId;
  final String fileName;
  final String fileType;
  final int? fileSizeBytes;
  final String? mimeType;
  final String driveFileId;
  final String driveWebViewLink;
  final String? driveFolderId;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? vendorName;
  final DateTime syncedAt;
  final String syncStatus; // 'success', 'failed', 'pending'
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriveSyncLog({
    required this.id,
    required this.businessOwnerId,
    required this.fileName,
    required this.fileType,
    this.fileSizeBytes,
    this.mimeType,
    required this.driveFileId,
    required this.driveWebViewLink,
    this.driveFolderId,
    this.relatedEntityType,
    this.relatedEntityId,
    this.vendorName,
    required this.syncedAt,
    required this.syncStatus,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriveSyncLog.fromJson(Map<String, dynamic> json) {
    return DriveSyncLog(
      id: json['id'] as String? ?? '',
      businessOwnerId: json['business_owner_id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      fileType: json['file_type'] as String? ?? '',
      fileSizeBytes: json['file_size_bytes'] as int?,
      mimeType: json['mime_type'] as String?,
      driveFileId: json['drive_file_id'] as String? ?? '',
      driveWebViewLink: json['drive_web_view_link'] as String? ?? '',
      driveFolderId: json['drive_folder_id'] as String?,
      relatedEntityType: json['related_entity_type'] as String?,
      relatedEntityId: json['related_entity_id'] as String?,
      vendorName: json['vendor_name'] as String?,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at'] as String)
          : DateTime.now(),
      syncStatus: json['sync_status'] as String? ?? 'success',
      errorMessage: json['error_message'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
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
      'synced_at': syncedAt.toIso8601String(),
      'sync_status': syncStatus,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String getFileTypeLabel() {
    const labels = {
      'invoice': 'Invois',
      'thermal_invoice': 'Invois Thermal',
      'claim_statement': 'Penyata Tuntutan',
      'thermal_claim': 'Penyata Thermal',
      'receipt_a5': 'Resit A5',
    };
    return labels[fileType] ?? fileType;
  }
}


