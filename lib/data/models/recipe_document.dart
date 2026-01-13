/// Model for recipe document (file or text)
class RecipeDocument {
  final String id;
  final String businessOwnerId;
  final String title;
  final String? description;
  final String? categoryId;
  final String contentType; // 'file' or 'text'
  
  // File fields (if contentType = 'file')
  final String? fileName;
  final String? filePath;
  final String? fileType; // pdf, jpg, jpeg, png
  final int? fileSize; // bytes
  
  // Text content (if contentType = 'text')
  final String? textContent;
  
  // Organization
  final List<String> tags;
  final bool isFavourite;
  
  // Integration
  final String? linkedRecipeId;
  
  // Metadata
  final DateTime uploadedAt;
  final DateTime? lastViewedAt;
  final int viewCount;
  final String? source; // e.g., "Facebook Group PJJ"
  
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeDocument({
    required this.id,
    required this.businessOwnerId,
    required this.title,
    this.description,
    this.categoryId,
    required this.contentType,
    this.fileName,
    this.filePath,
    this.fileType,
    this.fileSize,
    this.textContent,
    this.tags = const [],
    this.isFavourite = false,
    this.linkedRecipeId,
    required this.uploadedAt,
    this.lastViewedAt,
    this.viewCount = 0,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Supabase JSON
  factory RecipeDocument.fromJson(Map<String, dynamic> json) {
    return RecipeDocument(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      contentType: json['content_type'] as String,
      fileName: json['file_name'] as String?,
      filePath: json['file_path'] as String?,
      fileType: json['file_type'] as String?,
      fileSize: json['file_size'] != null ? (json['file_size'] as num).toInt() : null,
      textContent: json['text_content'] as String?,
      tags: json['tags'] != null 
          ? List<String>.from(json['tags'] as List)
          : [],
      isFavourite: json['is_favourite'] as bool? ?? false,
      linkedRecipeId: json['linked_recipe_id'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      lastViewedAt: json['last_viewed_at'] != null
          ? DateTime.parse(json['last_viewed_at'] as String)
          : null,
      viewCount: json['view_count'] as int? ?? 0,
      source: json['source'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'content_type': contentType,
      'file_name': fileName,
      'file_path': filePath,
      'file_type': fileType,
      'file_size': fileSize,
      'text_content': textContent,
      'tags': tags,
      'is_favourite': isFavourite,
      'linked_recipe_id': linkedRecipeId,
      'uploaded_at': uploadedAt.toIso8601String(),
      'last_viewed_at': lastViewedAt?.toIso8601String(),
      'view_count': viewCount,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create copy with updated fields
  RecipeDocument copyWith({
    String? id,
    String? businessOwnerId,
    String? title,
    String? description,
    String? categoryId,
    String? contentType,
    String? fileName,
    String? filePath,
    String? fileType,
    int? fileSize,
    String? textContent,
    List<String>? tags,
    bool? isFavourite,
    String? linkedRecipeId,
    DateTime? uploadedAt,
    DateTime? lastViewedAt,
    int? viewCount,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecipeDocument(
      id: id ?? this.id,
      businessOwnerId: businessOwnerId ?? this.businessOwnerId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      contentType: contentType ?? this.contentType,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      textContent: textContent ?? this.textContent,
      tags: tags ?? this.tags,
      isFavourite: isFavourite ?? this.isFavourite,
      linkedRecipeId: linkedRecipeId ?? this.linkedRecipeId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      viewCount: viewCount ?? this.viewCount,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if document is a file
  bool get isFile => contentType == 'file';

  /// Check if document is text
  bool get isText => contentType == 'text';

  /// Get file extension
  String? get fileExtension {
    if (fileName == null) return null;
    final parts = fileName!.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : null;
  }

  /// Get formatted file size
  String? get formattedFileSize {
    if (fileSize == null) return null;
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get display icon based on content type
  String get displayIcon {
    if (isFile) {
      switch (fileType?.toLowerCase()) {
        case 'pdf':
          return '📄';
        case 'jpg':
        case 'jpeg':
        case 'png':
          return '🖼️';
        default:
          return '📎';
      }
    }
    return '📝';
  }
}
