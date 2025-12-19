import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      final host = uri.host;

      if (kDebugMode) {
        print('[ApiConfig] Current host: $host');
        print('[ApiConfig] Full URI: ${uri.toString()}');
      }

      if (host.contains('onrender.com') ||
          host.contains('khonobuzz-web')) {
        final backendUrl = 'https://khonobuzz-backend-i24f.onrender.com';
        if (kDebugMode) {
          print(
            '[ApiConfig] Detected production environment, using backend: $backendUrl',
          );
        }
        return backendUrl;
      }
      if (kDebugMode) {
        print(
          '[ApiConfig] Detected local development, using: http://localhost:5000',
        );
      }
      return 'http://localhost:5000';
    }

    if (!kDebugMode) {
      final backendUrl = 'https://khonobuzz-backend-i24f.onrender.com';
      return backendUrl;
    }

    try {
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      if (isAndroid) {
        final backendUrl = 'http://10.0.2.2:5000';
        if (kDebugMode) {
          print(
            '[ApiConfig] Android platform detected, using: $backendUrl',
          );
        }
        return backendUrl;
      }
    } catch (_) {
    }
    
    if (kDebugMode) {
      print(
        '[ApiConfig] Mobile/Desktop platform, using: http://localhost:5000',
      );
    }
    return 'http://localhost:5000';
  }

  // API endpoints
  static String get usersEndpoint => '$baseUrl/api/users';
  static String get authRegisterEndpoint => '$baseUrl/api/auth/register';
  static String get authLoginEndpoint => '$baseUrl/api/auth/login';
  static String authTokenEndpoint(String email) =>
      '$baseUrl/api/auth/token?email=${Uri.encodeComponent(email)}';
  static String get pdhSyncUserEndpoint => '$baseUrl/api/pdh/sync-user';
  static String pdhUpdateUserEndpoint(String uid) =>
      '$baseUrl/api/pdh/update-user/$uid';
  static String get skillsHeatmapSyncUserEndpoint =>
      '$baseUrl/api/skills-heatmap/sync-user';
  static String skillsHeatmapUpdateUserEndpoint(String uid) =>
      '$baseUrl/api/skills-heatmap/update-user/$uid';
  static String userEndpoint(String userId) => '$baseUrl/api/users/$userId';
  static String deleteUserEndpoint(String userId) => '$baseUrl/api/users/$userId';
}
