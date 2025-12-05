import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  // Automatically detect environment and use appropriate backend URL
  // For production web (deployed on Render): use Render backend
  // For local development: use localhost
  static String get baseUrl {
    if (kIsWeb) {
      // Check if running on production domain (Render)
      final uri = Uri.base;
      final host = uri.host;

      // Debug logging to help identify connection issues
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
      // For local web development
      if (kDebugMode) {
        print(
          '[ApiConfig] Detected local development, using: http://localhost:5000',
        );
      }
      return 'http://localhost:5000';
    }
    // For mobile/desktop platforms
    // Android emulator uses 10.0.2.2 to access host machine's localhost
    // iOS simulator and desktop use localhost
    // Check if running on Android
    try {
      // Import Platform only when needed to avoid web compilation issues
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      if (isAndroid) {
        // Android emulator needs special IP to access host machine
        final backendUrl = 'http://10.0.2.2:5000';
        if (kDebugMode) {
          print(
            '[ApiConfig] Android platform detected, using: $backendUrl',
          );
        }
        return backendUrl;
      }
    } catch (_) {
      // If Platform is not available, fall back to localhost
    }
    
    // For iOS, desktop, and other platforms, use localhost
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
