import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_alert.dart';
import '../config/api_config.dart';

class AdminAlertApiException implements Exception {
  final int statusCode;
  final String body;

  const AdminAlertApiException(this.statusCode, this.body);

  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'AdminAlertApiException($statusCode): $body';
}

class AdminAlertService {
  static Future<void> publishAdminChange({
    required String actorEmail,
    required String title,
    required String message,
    required String area,
    Map<String, dynamic> details = const {},
    List<String> targetRoles = const ['admin', 'staff'],
    bool requiresAck = false,
    String effectiveDateIso = '',
  }) async {
    final normalizedRoles = targetRoles
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final response = await http.post(
      Uri.parse(ApiConfig.adminNotificationsEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'actorEmail': actorEmail.trim().toLowerCase(),
        'title': title.trim(),
        'message': message.trim(),
        'area': area.trim(),
        'details': details,
        'targetRoles': normalizedRoles,
        'requiresAck': requiresAck,
        'effectiveDateIso': effectiveDateIso.trim(),
      }),
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw AdminAlertApiException(
        response.statusCode,
        response.body,
      );
    }
  }

  static Future<List<AdminAlert>> fetchAlertsForRole(
    String role, {
    String userEmail = '',
    int limit = 30,
  }) async {
    final normalizedRole = role.trim().toLowerCase();
    if (normalizedRole.isEmpty) {
      return const [];
    }

    final response = await http.get(
      Uri.parse(
        '${ApiConfig.adminNotificationsEndpoint}?role=${Uri.encodeComponent(normalizedRole)}&userEmail=${Uri.encodeComponent(userEmail.trim().toLowerCase())}&limit=$limit',
      ),
    );
    if (response.statusCode != 200) {
      throw AdminAlertApiException(
        response.statusCode,
        response.body,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['alerts'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AdminAlert.fromApi)
        .toList(growable: false);
  }

  static Future<void> clearAlertsForUser({
    required String role,
    required String userEmail,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.adminNotificationsClearEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role.trim().toLowerCase(),
        'userEmail': userEmail.trim().toLowerCase(),
      }),
    );
    if (response.statusCode != 200) {
      throw AdminAlertApiException(
        response.statusCode,
        response.body,
      );
    }
  }

  static Future<void> dismissAlertForUser({
    required String role,
    required String userEmail,
    required String alertId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminNotificationsEndpoint}/dismiss'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role.trim().toLowerCase(),
        'userEmail': userEmail.trim().toLowerCase(),
        'alertId': alertId.trim(),
      }),
    );
    if (response.statusCode != 200) {
      throw AdminAlertApiException(
        response.statusCode,
        response.body,
      );
    }
  }

  static Future<void> acknowledgeAlert({
    required String userEmail,
    required String alertId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminNotificationsEndpoint}/ack'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userEmail': userEmail.trim().toLowerCase(),
        'alertId': alertId.trim(),
      }),
    );
    if (response.statusCode != 200) {
      throw AdminAlertApiException(
        response.statusCode,
        response.body,
      );
    }
  }
}
