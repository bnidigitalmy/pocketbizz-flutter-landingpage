class PlannerCategory {
  final String id;
  final String name;
  final String? color; // hex color
  final String? icon; // icon name
  final DateTime createdAt;
  final DateTime updatedAt;

  PlannerCategory({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlannerCategory.fromJson(Map<String, dynamic> json) {
    DateTime? _parseTs(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    return PlannerCategory(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      createdAt: _parseTs(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseTs(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'icon': icon,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

