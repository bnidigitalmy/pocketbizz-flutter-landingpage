class PlannerComment {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;

  PlannerComment({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory PlannerComment.fromJson(Map<String, dynamic> json) {
    return PlannerComment(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      userId: json['user_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };

  PlannerComment copyWith({
    String? id,
    String? userId,
    String? text,
    DateTime? createdAt,
  }) {
    return PlannerComment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


