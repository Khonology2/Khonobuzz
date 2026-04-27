import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAlert {
  final String id;
  final String title;
  final String message;
  final String area;
  final String actorEmail;
  final DateTime createdAt;
  final Map<String, dynamic> details;

  const AdminAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.area,
    required this.actorEmail,
    required this.createdAt,
    required this.details,
  });

  factory AdminAlert.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAtRaw = data['createdAt'];
    DateTime createdAt = DateTime.now().toUtc();

    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate().toUtc();
    } else if (data['createdAtIso'] is String) {
      createdAt =
          DateTime.tryParse((data['createdAtIso'] as String).trim())?.toUtc() ??
          createdAt;
    }

    return AdminAlert(
      id: doc.id,
      title: (data['title'] as String? ?? 'Admin update').trim(),
      message: (data['message'] as String? ?? '').trim(),
      area: (data['area'] as String? ?? 'general').trim(),
      actorEmail: (data['actorEmail'] as String? ?? '').trim(),
      createdAt: createdAt,
      details: Map<String, dynamic>.from(data['details'] as Map? ?? const {}),
    );
  }

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
    );
  }
}
