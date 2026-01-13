/// Model for recipe document category (custom categories)
class RecipeDocumentCategory {
  final String id;
  final String businessOwnerId;
  final String name;
  final String? icon; // emoji or icon name
  final String? color; // hex color
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecipeDocumentCategory({
    required this.id,
    required this.businessOwnerId,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Supabase JSON
  factory RecipeDocumentCategory.fromJson(Map<String, dynamic> json) {
    return RecipeDocumentCategory(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'name': name,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create copy with updated fields
  RecipeDocumentCategory copyWith({
    String? id,
    String? businessOwnerId,
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecipeDocumentCategory(
      id: id ?? this.id,
      businessOwnerId: businessOwnerId ?? this.businessOwnerId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get display icon (default if not set)
  String get displayIcon => icon ?? '📁';
}
