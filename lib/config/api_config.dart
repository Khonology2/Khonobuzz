class ApiConfig {
  // For local development:
  // - Use 'http://localhost:5000' for iOS simulator or web
  // - Use 'http://10.0.2.2:5000' for Android emulator
  // - Use 'http://127.0.0.1:5000' for desktop
  static const String baseUrl = 'http://localhost:5000';

  // For production, use:
  // static const String baseUrl = 'https://khonobuzz-backend.onrender.com';

  // API endpoints
  static String get usersEndpoint => '$baseUrl/api/users';
  static String get authRegisterEndpoint => '$baseUrl/api/auth/register';
  static String get authLoginEndpoint => '$baseUrl/api/auth/login';
  static String authTokenEndpoint(String email) => '$baseUrl/api/auth/token?email=${Uri.encodeComponent(email)}';
  static String get pdhSyncUserEndpoint => '$baseUrl/api/pdh/sync-user';
  static String pdhUpdateUserEndpoint(String uid) =>
      '$baseUrl/api/pdh/update-user/$uid';
  static String get skillsHeatmapSyncUserEndpoint =>
      '$baseUrl/api/skills-heatmap/sync-user';
  static String skillsHeatmapUpdateUserEndpoint(String uid) =>
      '$baseUrl/api/skills-heatmap/update-user/$uid';
  static String userEndpoint(String userId) => '$baseUrl/api/users/$userId';
}
