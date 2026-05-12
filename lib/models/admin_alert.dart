class AdminAlert {
  final String id;
  final String title;
  final String message;
  final String area;
  final String actorEmail;
  final DateTime createdAt;
  final Map<String, dynamic> details;
  final bool requiresAck;
  final bool acknowledged;
  final int acknowledgedCount;
  final int targetCount;
  final String effectiveDateIso;

  const AdminAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.area,
    required this.actorEmail,
    required this.createdAt,
    required this.details,
    required this.requiresAck,
    required this.acknowledged,
    required this.acknowledgedCount,
    required this.targetCount,
    required this.effectiveDateIso,
  });

  factory AdminAlert.fromApi(Map<String, dynamic> json) {
    final createdAtIso = (json['createdAtIso'] as String? ?? '').trim();
    final createdAt = DateTime.tryParse(createdAtIso)?.toUtc() ?? DateTime.now().toUtc();
    return AdminAlert(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? 'Admin update').trim(),
      message: (json['message'] as String? ?? '').trim(),
      area: (json['area'] as String? ?? 'general').trim(),
      actorEmail: (json['actorEmail'] as String? ?? '').trim(),
      createdAt: createdAt,
      details: Map<String, dynamic>.from(json['details'] as Map? ?? const {}),
      requiresAck: (json['requiresAck'] as bool?) ?? false,
      acknowledged: (json['acknowledged'] as bool?) ?? false,
      acknowledgedCount: (json['acknowledgedCount'] as num?)?.toInt() ?? 0,
      targetCount: (json['targetCount'] as num?)?.toInt() ?? 0,
      effectiveDateIso: (json['effectiveDateIso'] as String? ?? '').trim(),
    );
  }
}
