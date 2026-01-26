import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      final host = uri.host;
      final queryParams = uri.queryParameters;

      if (kDebugMode) {
        print('[ApiConfig] Current host: $host');
        print('[ApiConfig] Full URI: ${uri.toString()}');
      }

      // Explicit overrides via query parameter
      if (queryParams['backend'] == 'prod') {
        const hostedBackend = 'https://khonobuzz-backend-i24f.onrender.com';
        if (kDebugMode) {
          print(
            '[ApiConfig] Web: backend=prod override detected, using: $hostedBackend',
          );
        }
        return hostedBackend;
      }
      if (queryParams['backend'] == 'local') {
        const localBackend = 'http://localhost:5000';
        if (kDebugMode) {
          print(
            '[ApiConfig] Web: backend=local override detected, using: $localBackend',
          );
        }
        return localBackend;
      }

      // Hosted web builds (onrender) use the hosted backend
      if (host.contains('onrender.com') || host.contains('khonobuzz-web')) {
        const hostedBackend = 'https://khonobuzz-backend-i24f.onrender.com';
        if (kDebugMode) {
          print(
            '[ApiConfig] Web: detected hosted environment, using backend: $hostedBackend',
          );
        }
        return hostedBackend;
      }

      // Default for local web development is the local backend
      const localBackend = 'http://localhost:5000';
      if (kDebugMode) {
        print(
          '[ApiConfig] Web: detected local development, using backend: $localBackend (host=$host)',
        );
      }
      return localBackend;
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
  static String userByEmailEndpoint(String email) =>
      '$baseUrl/api/users/by-email?email=${Uri.encodeComponent(email)}';
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
  static String onboardingUpdateUserEndpoint(String userId) => '$baseUrl/api/onboarding/update-user/$userId';
}
