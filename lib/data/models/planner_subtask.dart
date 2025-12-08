class PlannerSubtask {
  final String id;
  final String title;
  final bool done;
  final DateTime? completedAt;

  PlannerSubtask({
    required this.id,
    required this.title,
    required this.done,
    this.completedAt,
  });

  factory PlannerSubtask.fromJson(Map<String, dynamic> json) {
    return PlannerSubtask(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'completed_at': completedAt?.toIso8601String(),
      };

  PlannerSubtask copyWith({
    String? id,
    String? title,
    bool? done,
    DateTime? completedAt,
  }) {
    return PlannerSubtask(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}


