import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Automatically detect environment and use appropriate backend URL
  // For production web (deployed on Netlify or Render): use Render backend
  // For local development: use localhost
  static String get baseUrl {
    if (kIsWeb) {
      // Check if running on production domain (Netlify or Render)
      final uri = Uri.base;
      if (uri.host.contains('netlify.app') ||
          uri.host.contains('onrender.com') ||
          uri.host.contains('khonobuzz-web')) {
        return 'https://khonobuzz-backend-i24f.onrender.com';
      }
      // For local web development
      return 'http://localhost:5000';
    }
    // For mobile/desktop platforms
    // Android emulator uses 10.0.2.2, iOS simulator uses localhost
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
}
