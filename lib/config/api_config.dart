import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'dart:io' show Platform;

class ApiConfig {
  // Environment variable names
  static const String _backendUrlEnv = 'BACKEND_URL';
  static const String _corsOriginEnv = 'CORS_ORIGIN';

  static String get baseUrl {
    // First, check for environment variables (works for mobile/desktop and some web deployments)
    final envBackendUrl = _getEnvVar(_backendUrlEnv);
    if (envBackendUrl != null && envBackendUrl.isNotEmpty) {
      if (kDebugMode) {
        print('[ApiConfig] Using backend URL from environment: $envBackendUrl');
      }
      return envBackendUrl;
    }

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
        const hostedBackend = String.fromEnvironment(
          _backendUrlEnv,
          defaultValue: 'https://khonobuzz-central-hub.onrender.com',
        );
        if (kDebugMode) {
          print(
            '[ApiConfig] Web: backend=prod override detected, using: $hostedBackend',
          );
        }
        return hostedBackend;
      }
      if (queryParams['backend'] == 'local') {
        const localBackend = String.fromEnvironment(
          'LOCAL_BACKEND_URL',
          defaultValue: 'http://localhost:5000',
        );
        if (kDebugMode) {
          print(
            '[ApiConfig] Web: backend=local override detected, using: $localBackend',
          );
        }
        return localBackend;
      }

      // Frontend is at khono-buzz-central-hub-web (Static Site);
      // Backend is at khonobuzz-central-hub (Web Service) - separate Render services
      if (host.contains('onrender.com') || host.contains('khonobuzz-web')) {
        const hostedBackend = String.fromEnvironment(
          _backendUrlEnv,
          defaultValue: 'https://khonobuzz-central-hub.onrender.com',
        );
        if (kDebugMode) {
          print(
            '[ApiConfig] Web: detected hosted frontend, using backend: $hostedBackend',
          );
        }
        return hostedBackend;
      }

      // Default for local web development is the local backend
      const localBackend = String.fromEnvironment(
        'LOCAL_BACKEND_URL',
        defaultValue: 'http://localhost:5000',
      );
      if (kDebugMode) {
        print(
          '[ApiConfig] Web: detected local development, using backend: $localBackend (host=$host)',
        );
      }
      return localBackend;
    }

    if (!kDebugMode) {
      final backendUrl = String.fromEnvironment(
        _backendUrlEnv,
        defaultValue: 'https://khonobuzz-central-hub.onrender.com',
      );
      return backendUrl;
    }

    try {
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      if (isAndroid) {
        final backendUrl = String.fromEnvironment(
          'ANDROID_BACKEND_URL',
          defaultValue: 'http://10.0.2.2:5000',
        );
        if (kDebugMode) {
          print('[ApiConfig] Android platform detected, using: $backendUrl');
        }
        return backendUrl;
      }
    } catch (_) {}

    if (kDebugMode) {
      print(
        '[ApiConfig] Mobile/Desktop platform, using: http://localhost:5000',
      );
    }
    return 'http://localhost:5000';
  }

  // Helper method to get environment variables
  static String? _getEnvVar(String name) {
    try {
      return Platform.environment[name];
    } catch (e) {
      // Platform.environment might not be available on all platforms
      return null;
    }
  }

  // CORS origin for reference (frontend URL for backend CORS config)
  static String get corsOrigin {
    return String.fromEnvironment(
      _corsOriginEnv,
      defaultValue: 'https://khono-buzz-central-hub-web.onrender.com',
    );
  }

  // API endpoints
  static String get usersEndpoint => '$baseUrl/api/users';
  static String get authRegisterEndpoint => '$baseUrl/api/auth/register';
  static String get authLoginEndpoint => '$baseUrl/api/auth/login';
  static String userByEmailEndpoint(String email) =>
      '$baseUrl/api/users/by-email?email=${Uri.encodeComponent(email)}';
  static String authTokenEndpoint(
    String email, {
    String? module,
    String? role,
    String? theme,
  }) {
    var base = '$baseUrl/api/auth/token?email=${Uri.encodeComponent(email)}';
    if (theme != null && theme.isNotEmpty) {
      base = '$base&theme=${Uri.encodeComponent(theme)}';
    }
    if (module != null && module.isNotEmpty) {
      final encodedModule = Uri.encodeComponent(module);
      if (role != null && role.isNotEmpty) {
        return '$base&module=$encodedModule&role=${Uri.encodeComponent(role)}';
      }
      return '$base&module=$encodedModule';
    }
    return base;
  }

  static String get pdhSyncUserEndpoint => '$baseUrl/api/pdh/sync-user';
  static String pdhUpdateUserEndpoint(String uid) =>
      '$baseUrl/api/pdh/update-user/$uid';
  static String get skillsHeatmapSyncUserEndpoint =>
      '$baseUrl/api/skills-heatmap/sync-user';
  static String skillsHeatmapUpdateUserEndpoint(String uid) =>
      '$baseUrl/api/skills-heatmap/update-user/$uid';
  static String userEndpoint(String userId) => '$baseUrl/api/users/$userId';
  static String deleteUserEndpoint(String userId) =>
      '$baseUrl/api/users/$userId';
  static String onboardingUpdateUserEndpoint(String userId) =>
      '$baseUrl/api/onboarding/update-user/$userId';
  static String get departmentsEndpoint => '$baseUrl/api/departments';
  static String get designationsEndpoint => '$baseUrl/api/designations';
  static String get entitiesEndpoint => '$baseUrl/api/entities';
  static String get adminNotificationsEndpoint => '$baseUrl/api/admin/notifications';
  static String get adminNotificationsClearEndpoint =>
      '$baseUrl/api/admin/notifications/clear';
}
