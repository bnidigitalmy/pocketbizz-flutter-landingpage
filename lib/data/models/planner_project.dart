class PlannerProject {
  final String id;
  final String name;
  final String? description;
  final String? color; // hex color
  final String? icon; // icon name
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlannerProject({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.icon,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlannerProject.fromJson(Map<String, dynamic> json) {
    DateTime? _parseTs(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    return PlannerProject(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: _parseTs(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseTs(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'icon': icon,
        'is_archived': isArchived,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

