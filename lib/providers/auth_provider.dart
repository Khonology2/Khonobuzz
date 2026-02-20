import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import '../utils/pdh_firebase.dart' show syncUserToPDH, syncUserToSkillsHeatmap;
import '../config/api_config.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userRole; // New: To store the user's role
  bool _userAlreadyOnboarded =
      false; // New: State to indicate if user already onboarded
  int? _initialScreenIndex; // New: Track initial screen index after login
  int?
  _currentScreenIndex; // Track current screen index for refresh persistence
  String? _userModuleAccess; // Store current user's module access
  String? _userToken; // Store current user's encrypted token
  String? _userProfileImageUrl; // Store current user's profile image URL
  String? _userProfilePublicId; // Store current user's profile image public ID
  bool _isSpecialSession = false; // Track special session state
  Map<String, dynamic>? _cachedProfileData; // Cache for prefetched profile data

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userRole => _userRole; // New: Getter for user role
  bool get userAlreadyOnboarded =>
      _userAlreadyOnboarded; // New: Getter for onboarding status
  int? get initialScreenIndex =>
      _initialScreenIndex; // New: Getter for initial screen index
  int? get currentScreenIndex =>
      _currentScreenIndex; // Getter for current screen index
  String? get userModuleAccess => _userModuleAccess; // Getter for module access
  String? get userToken => _userToken; // Getter for user token
  String? get userProfileImageUrl =>
      _userProfileImageUrl; // Getter for profile image URL
  String? get userProfilePublicId =>
      _userProfilePublicId; // Getter for profile image public ID
  bool get isSpecialSession => _isSpecialSession; // Getter for special session
  Map<String, dynamic>? get cachedProfileData =>
      _cachedProfileData; // Getter for cached profile data

  AuthProvider() {
    _loadAuthState();
  }

  Future<http.Response> _postWithTimeoutAndRetry(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    int maxRetries = 1,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    http.Response? lastResponse;
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final attemptStart = DateTime.now().millisecondsSinceEpoch;
      try {
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(
              timeout,
              onTimeout: () {
                throw TimeoutException(
                  'Request timed out after ${timeout.inSeconds} seconds.',
                );
              },
            );
        final elapsed = DateTime.now().millisecondsSinceEpoch - attemptStart;
        debugPrint(
          '[AuthProvider] POST ${url.path} attempt ${attempt + 1} '
          'completed in ${elapsed}ms with status ${response.statusCode}',
        );
        lastResponse = response;
        if (response.statusCode < 500) {
          return response;
        }
      } on TimeoutException catch (e) {
        lastError = e;
        final elapsed = DateTime.now().millisecondsSinceEpoch - attemptStart;
        debugPrint(
          '[AuthProvider] POST ${url.path} attempt ${attempt + 1} '
          'timed out after ${elapsed}ms: ${e.message}',
        );
      } catch (e) {
        lastError = e;
        final elapsed = DateTime.now().millisecondsSinceEpoch - attemptStart;
        debugPrint(
          '[AuthProvider] POST ${url.path} attempt ${attempt + 1} '
          'failed after ${elapsed}ms: $e',
        );
        if (e is! TimeoutException) {
          break;
        }
      }
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    if (lastResponse != null) {
      return lastResponse;
    }
    if (lastError is TimeoutException) {
      throw lastError;
    }
    throw Exception(lastError?.toString() ?? 'Request failed after retries');
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _userEmail = prefs.getString('userEmail');
    _userRole = prefs.getString('userRole');
    _initialScreenIndex = prefs.getInt('initialScreenIndex');
    _currentScreenIndex = prefs.getInt('currentScreenIndex');
    _userModuleAccess = prefs.getString('userModuleAccess');
    _userToken = prefs.getString('userToken');
    _userProfileImageUrl = prefs.getString('userProfileImageUrl');
    _userProfilePublicId = prefs.getString('userProfilePublicId');
    _isSpecialSession = prefs.getBool('_spSess') ?? false;

    debugPrint(
      '[AuthProvider] _loadAuthState - userProfileImageUrl: $_userProfileImageUrl',
    );
    debugPrint(
      '[AuthProvider] _loadAuthState - userProfilePublicId: $_userProfilePublicId',
    );

    notifyListeners();
  }

  Future<bool> login(
    String email, {
    String? role,
    String firstName = '', // Made optional with default empty string
    String lastName = '', // Made optional with default empty string
    String? department, // Changed to nullable String?
    String designation = '', // Made optional with default empty string
  }) async {
    // Modified: added role and all onboarding parameters

    final url = Uri.parse(ApiConfig.authRegisterEndpoint);

    // Debug logging
    debugPrint('[AuthProvider] Attempting to register/login with URL: $url');
    debugPrint('[AuthProvider] Backend base URL: ${ApiConfig.baseUrl}');

    try {
      final start = DateTime.now().millisecondsSinceEpoch;
      final response = await _postWithTimeoutAndRetry(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': 'password',
          'name': '$firstName $lastName',
          'firstName': firstName,
          'lastName': lastName,
          'role': role ?? 'Staff',
          'department': department ?? '',
          'designation': designation,
        }),
      );
      final elapsed = DateTime.now().millisecondsSinceEpoch - start;

      debugPrint(
        '[AuthProvider] Registration/login response '
        '${response.statusCode} in ${elapsed}ms',
      );
      debugPrint('[AuthProvider] Response body: ${response.body}');

      if (response.statusCode == 201) {
        // User registered successfully
        final responseData = json.decode(response.body);

        final userPayload = responseData['user'] as Map<String, dynamic>? ?? {};
        final String uid = userPayload['id'] ?? '';
        // Get token from response if available
        final String? tokenFromResponse = responseData.containsKey('token')
            ? responseData['token'] as String?
            : null;

        if (uid.isNotEmpty) {
          final Map<String, dynamic> userData = {
            'email': email,
            'password': 'password',
            'name': '$firstName $lastName',
            'role': role ?? 'Staff',
            'status': 'Pending',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'entity': '',
            'department': department ?? '',
            'designation': designation,
          };
          final Map<String, dynamic> onboardingData = {
            'user_id': uid,
            'email': email,
            'name': firstName,
            'surname': lastName,
            'fullName': '$firstName $lastName'.trim(),
            'department': department ?? '',
            'designation': designation,
            'status': 'Pending',
            'role': role ?? 'Staff',
            'first_valid': DateTime.utc(2025, 9, 25).toIso8601String(),
            'inserted_by': email,
            'last_valid': DateTime.utc(2039, 12, 31).toIso8601String(),
            'onboarding_id': uid,
            'status_id': '',
            'updated_by': email,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'entity': '',
          };

          // Include token in onboarding data if available from response
          if (tokenFromResponse != null) {
            onboardingData['token'] = tokenFromResponse;
            onboardingData['token_updated_at'] = DateTime.now()
                .toUtc()
                .toIso8601String();
          }

          // Run syncs in background (non-blocking) to speed up login
          syncUserToPDH(userData, onboardingData, uid).catchError((e) {
            debugPrint(
              'Failed to sync new user to PDH during registration: $e',
            );
          });
          syncUserToSkillsHeatmap(userData, onboardingData, uid).catchError((
            e,
          ) {
            debugPrint(
              'Failed to sync new user to Skills Heatmap during registration: $e',
            );
          });
        }

        // Batch all SharedPreferences writes together for better performance
        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userEmail = email;
        _userRole = userPayload['role'] ?? role ?? 'Staff';
        _initialScreenIndex = 9;
        _currentScreenIndex = 9;
        _userAlreadyOnboarded = false;

        // Batch all writes
        await Future.wait([
          prefs.setBool('isAuthenticated', true),
          prefs.setString('userEmail', email),
          prefs.setString('userRole', _userRole!),
          prefs.setInt('initialScreenIndex', 9),
          prefs.setInt('currentScreenIndex', 9),
          if (tokenFromResponse != null)
            prefs.setString('userToken', tokenFromResponse),
        ]);

        if (tokenFromResponse != null) {
          _userToken = tokenFromResponse;
        }

        notifyListeners();

        // Run these in parallel to speed up login
        await Future.wait([
          fetchCurrentUserModuleAccess(),
          if (_userToken == null) fetchUserToken(),
        ]);

        return true; // Indicate success
      } else if (response.statusCode == 409) {
        // User already exists; attempt fallback login to fetch real role
        final fallbackSuccess = await _attemptFallbackLogin(email);
        return fallbackSuccess;
      } else {
        // Handle other errors
        _isAuthenticated = false;
        _userAlreadyOnboarded = false; // Reset onboarding status on failure
        notifyListeners();
        return false; // Indicate failure
      }
    } on TimeoutException catch (e) {
      debugPrint('[AuthProvider] Registration/login timed out: ${e.message}');
      _isAuthenticated = false;
      _userAlreadyOnboarded = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Enhanced error logging
      debugPrint('[AuthProvider] ERROR during registration/login: $e');
      debugPrint('[AuthProvider] Error type: ${e.runtimeType}');
      if (e is Exception) {
        debugPrint('[AuthProvider] Exception details: ${e.toString()}');
      }
      _isAuthenticated = false;
      _userAlreadyOnboarded = false; // Reset onboarding status on error
      notifyListeners();
      return false; // Indicate failure
    }
  }

  Future<bool> manualLogin(String email, {bool isSpecialAccess = false}) async {
    final url = Uri.parse(ApiConfig.authLoginEndpoint);

    try {
      final start = DateTime.now().millisecondsSinceEpoch;
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (isSpecialAccess) {
        headers['X-Session-Type'] = 'special';
      }

      final response = await _postWithTimeoutAndRetry(
        url,
        headers: headers,
        body: json.encode({'email': email}),
        maxRetries: 0,
        timeout: const Duration(seconds: 4),
      );
      final elapsed = DateTime.now().millisecondsSinceEpoch - start;
      debugPrint(
        '[AuthProvider] manualLogin response ${response.statusCode} in ${elapsed}ms',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        final prefs = await SharedPreferences.getInstance();
        final userPayload = responseData['user'] as Map<String, dynamic>? ?? {};

        if (userPayload['email'] == null) {
          _isAuthenticated = false;
          notifyListeners();
          return false;
        }

        _isAuthenticated = true;
        _isSpecialSession = isSpecialAccess;
        _userEmail = userPayload['email'] as String;
        _userRole = isSpecialAccess
            ? 'Admin'
            : (userPayload['role'] ?? 'Staff');
        _initialScreenIndex = 9;
        _currentScreenIndex = 9;

        // Extract module access from user payload if available (faster than separate API call)
        final moduleAccessRaw = userPayload['moduleAccess'] as String?;
        final moduleAccessRoleRaw = userPayload['moduleAccessRole'] as String?;
        _userModuleAccess = _deriveModuleAccessFromRole(
          moduleAccessRaw,
          moduleAccessRoleRaw,
        );

        // Extract profile image data from login response
        debugPrint('[AuthProvider] Login response userPayload: $userPayload');
        _userProfileImageUrl = userPayload['profileImageUrl'] as String?;
        _userProfilePublicId = userPayload['profileImagePublicId'] as String?;
        debugPrint(
          '[AuthProvider] Extracted profileImageUrl: $_userProfileImageUrl',
        );
        debugPrint(
          '[AuthProvider] Extracted profileImagePublicId: $_userProfilePublicId',
        );

        // Batch all SharedPreferences writes
        final writeTasks = <Future>[
          prefs.setBool('isAuthenticated', true),
          prefs.setString('userEmail', _userEmail!),
          prefs.setString('userRole', _userRole!),
          prefs.setInt('initialScreenIndex', 9),
          prefs.setInt('currentScreenIndex', 9),
          if (_userProfileImageUrl != null)
            prefs.setString('userProfileImageUrl', _userProfileImageUrl!),
          if (_userProfilePublicId != null)
            prefs.setString('userProfilePublicId', _userProfilePublicId!),
        ];

        // Get token from response if available
        if (responseData.containsKey('token') &&
            responseData['token'] != null) {
          _userToken = responseData['token'] as String?;
          if (_userToken != null && _userToken!.isNotEmpty) {
            writeTasks.add(prefs.setString('userToken', _userToken!));
          }
        }

        await Future.wait(writeTasks);
        if (isSpecialAccess) {
          await prefs.setBool('_spSess', true);
        }
        notifyListeners();

        _schedulePostLoginWarmup();

        return true;
      } else if (!isSpecialAccess &&
          (response.statusCode == 403 ||
              response.statusCode == 404 ||
              response.statusCode == 401)) {
        final success = await _attemptFallbackLogin(email);
        if (success) {
          return true;
        }
        _isAuthenticated = false;
        notifyListeners();
        return false;
      } else {
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }
    } on TimeoutException catch (_) {
      if (!isSpecialAccess) {
        final success = await _attemptFallbackLogin(email);
        if (success) {
          return true;
        }
      }
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (!isSpecialAccess &&
          (e.toString().contains('SocketException') ||
              e.toString().contains('Failed host lookup') ||
              e.toString().contains('Connection refused') ||
              e.toString().contains('timeout'))) {
        final success = await _attemptFallbackLogin(email);
        if (success) {
          return true;
        }
      }

      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  void _schedulePostLoginWarmup() {
    Future<void>(() async {
      try {
        await Future.wait([
          if (_userModuleAccess == null) fetchCurrentUserModuleAccess(),
          if (_userToken == null || _userToken!.isEmpty) fetchUserToken(),
          fetchUserProfileData(), // Prefetch detailed profile data
        ]);
      } catch (e) {
        debugPrint('[AuthProvider] Post-login warmup failed: $e');
      }
    });
  }

  // Prefetch detailed user profile data for faster profile screen loading
  Future<void> fetchUserProfileData() async {
    try {
      final email = _userEmail;
      if (email == null || email.isEmpty) {
        debugPrint('[AuthProvider] Cannot fetch profile data: no user email');
        return;
      }

      final url = Uri.parse(ApiConfig.userByEmailEndpoint(email));
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer ${_userToken ?? ''}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        Map<String, dynamic> userMap = {};
        if (decoded is Map<String, dynamic>) {
          if (decoded['user'] is Map<String, dynamic>) {
            userMap = decoded['user'] as Map<String, dynamic>;
          } else {
            userMap = decoded;
          }
        }

        // Update AuthProvider with profile image data if available
        final profileImageUrl = userMap['profileImageUrl'] as String?;
        final profileImagePublicId = userMap['profileImagePublicId'] as String?;

        if (profileImageUrl != null && profileImageUrl.isNotEmpty ||
            profileImagePublicId != null && profileImagePublicId.isNotEmpty) {
          await updateUserProfileImage(profileImageUrl, profileImagePublicId);
          debugPrint('[AuthProvider] Profile data prefetched successfully');
        }

        // Store other profile data for potential future use
        _cachedProfileData = userMap;
      } else {
        debugPrint(
          '[AuthProvider] Failed to prefetch profile data: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error prefetching profile data: $e');
    }
  }

  Future<bool> _attemptFallbackLogin(String email) async {
    final userCheckUrl = Uri.parse(ApiConfig.userByEmailEndpoint(email));
    try {
      final userCheckResponse = await http
          .get(userCheckUrl)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

      if (userCheckResponse.statusCode == 200) {
        final usersData = json.decode(userCheckResponse.body);
        final foundUser = usersData['user'] as Map<String, dynamic>?;

        if (foundUser != null) {
          final prefs = await SharedPreferences.getInstance();
          _isAuthenticated = true;
          _userEmail = foundUser['email'] ?? email;
          _userRole = foundUser['role'] ?? 'Staff';
          _initialScreenIndex = 9;
          _currentScreenIndex = 9;

          final moduleAccessRaw = foundUser['moduleAccess'] as String?;
          final moduleAccessRoleRaw = foundUser['moduleAccessRole'] as String?;
          _userModuleAccess = _deriveModuleAccessFromRole(
            moduleAccessRaw,
            moduleAccessRoleRaw,
          );

          await Future.wait([
            prefs.setBool('isAuthenticated', true),
            prefs.setString('userEmail', _userEmail!),
            prefs.setString('userRole', _userRole!),
            prefs.setInt('initialScreenIndex', 9),
            prefs.setInt('currentScreenIndex', 9),
          ]);

          notifyListeners();

          await Future.wait([
            if (_userModuleAccess == null) fetchCurrentUserModuleAccess(),
            fetchUserToken(),
          ]);

          return true;
        }
      } else if (userCheckResponse.statusCode == 404) {
        debugPrint('Fallback login: user not found for email $email');
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Fallback login failed: $e');
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = false;
    _userEmail = null;
    _userRole = null;
    _initialScreenIndex = null;
    _currentScreenIndex = null;
    _userModuleAccess = null;
    _userToken = null;
    _userProfileImageUrl = null;
    _userProfilePublicId = null;
    _isSpecialSession = false;
    await Future.wait([
      prefs.remove('isAuthenticated'),
      prefs.remove('userEmail'),
      prefs.remove('userRole'),
      prefs.remove('initialScreenIndex'),
      prefs.remove('currentScreenIndex'),
      prefs.remove('userModuleAccess'),
      prefs.remove('userToken'),
      prefs.remove('userProfileImageUrl'),
      prefs.remove('userProfilePublicId'),
      prefs.remove('_spSess'),
    ]);
    notifyListeners();
  }

  void clearInitialScreenIndex() {
    _initialScreenIndex = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('initialScreenIndex');
    });
    notifyListeners();
  }

  // Update user's profile image
  Future<void> updateUserProfileImage(
    String? imageUrl,
    String? publicId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    _userProfileImageUrl = imageUrl;
    _userProfilePublicId = publicId;
    await Future.wait([
      if (imageUrl != null) prefs.setString('userProfileImageUrl', imageUrl),
      if (publicId != null) prefs.setString('userProfilePublicId', publicId),
    ]);
    notifyListeners();
  }

  // Save current screen index for refresh persistence
  Future<void> saveCurrentScreenIndex(int index) async {
    _currentScreenIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentScreenIndex', index);
    notifyListeners();
  }

  // Derives moduleAccess from moduleAccessRole if moduleAccess is empty or incomplete
  static String? _deriveModuleAccessFromRole(
    String? moduleAccess,
    String? moduleAccessRole,
  ) {
    // If moduleAccess already has values, use it
    if (moduleAccess != null && moduleAccess.trim().isNotEmpty) {
      return moduleAccess;
    }

    // If moduleAccessRole is empty, return null
    if (moduleAccessRole == null || moduleAccessRole.trim().isEmpty) {
      return null;
    }

    // Extract module names from moduleAccessRole
    final parts = moduleAccessRole.split(',');
    final List<String> moduleNames = [];

    for (var part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('PDH')) {
        if (!moduleNames.contains('Personal Development Hub')) {
          moduleNames.add('Personal Development Hub');
        }
      } else if (trimmed.startsWith('Skills Heatmap')) {
        if (!moduleNames.contains('Resource & Capacity Skills Heatmap')) {
          moduleNames.add('Resource & Capacity Skills Heatmap');
        }
      } else if (trimmed.startsWith('Automated Recruitment Workflow')) {
        if (!moduleNames.contains('Automated Recruitment Workflow')) {
          moduleNames.add('Automated Recruitment Workflow');
        }
      } else if (trimmed.startsWith('Proposal & SOW Builder') ||
          trimmed.startsWith('SOW Builder')) {
        if (!moduleNames.contains('Proposal & SOW Builder')) {
          moduleNames.add('Proposal & SOW Builder');
        }
      } else if (trimmed.startsWith('Deliverables & Sprint Sign-Off Hub')) {
        if (!moduleNames.contains('Deliverables & Sprint Sign-Off Hub')) {
          moduleNames.add('Deliverables & Sprint Sign-Off Hub');
        }
      }
    }

    return moduleNames.isEmpty ? null : moduleNames.join(',');
  }

  // Set module access directly (useful when loading from cache)
  void setModuleAccess(String? moduleAccess) {
    _userModuleAccess = moduleAccess;
    notifyListeners();
  }

  // Fetch current user's module access from API
  // Optimized: Can accept pre-fetched moduleAccess to avoid API call
  Future<void> fetchCurrentUserModuleAccess({
    String? preFetchedModuleAccess,
  }) async {
    if (_userEmail == null) {
      _userModuleAccess = null;
      notifyListeners();
      return;
    }

    // If module access was pre-fetched (e.g., from UserProvider cache), use it
    if (preFetchedModuleAccess != null && preFetchedModuleAccess.isNotEmpty) {
      _userModuleAccess = preFetchedModuleAccess;
      notifyListeners();
      debugPrint('[AuthProvider] Module access loaded from cache');
      return;
    }

    try {
      // Use shorter timeout for faster failure
      final response = await http
          .get(Uri.parse(ApiConfig.usersEndpoint))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final usersData = json.decode(response.body);
        final users = usersData['users'] as List<dynamic>? ?? [];

        try {
          final foundUser = users.firstWhere(
            (u) =>
                u is Map<String, dynamic> &&
                u['email']?.toString().toLowerCase() ==
                    _userEmail!.toLowerCase(),
          );

          final moduleAccessRaw = foundUser['moduleAccess'] as String?;
          final moduleAccessRoleRaw = foundUser['moduleAccessRole'] as String?;

          // Derive moduleAccess from moduleAccessRole if moduleAccess is empty
          _userModuleAccess = _deriveModuleAccessFromRole(
            moduleAccessRaw,
            moduleAccessRoleRaw,
          );
          notifyListeners();
          debugPrint('[AuthProvider] Module access loaded from API');
        } catch (_) {
          _userModuleAccess = null;
          notifyListeners();
        }
      } else {
        _userModuleAccess = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user module access: $e');
      _userModuleAccess = null;
      notifyListeners();
    }
  }

  // Check if user has specific module access
  // Supports both short names (PDH, Skills Heatmap) and full names (Personal Development Hub, Resource & Capacity Skills Heatmap)
  bool hasModuleAccess(String moduleName) {
    if (_userModuleAccess == null || _userModuleAccess!.isEmpty) {
      return false;
    }
    final accessList = _userModuleAccess!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Direct match
    if (accessList.contains(moduleName)) {
      return true;
    }

    // Check for partial matches (e.g., "PDH" matches "Personal Development Hub")
    final moduleNameLower = moduleName.toLowerCase();
    for (var access in accessList) {
      final accessLower = access.toLowerCase();
      // Check if moduleName is contained in access or vice versa
      if (accessLower.contains(moduleNameLower) ||
          moduleNameLower.contains(accessLower)) {
        // Additional validation for specific module mappings
        if (moduleNameLower == 'pdh' &&
            (accessLower.contains('personal development hub') ||
                accessLower == 'pdh')) {
          return true;
        }
        if (moduleNameLower.contains('skills heatmap') &&
            (accessLower.contains('skills heatmap') ||
                accessLower.contains('resource & capacity'))) {
          return true;
        }
        if (moduleNameLower.contains('recruitment') &&
            accessLower.contains('recruitment')) {
          return true;
        }
      }
    }

    return false;
  }

  // Fetch user token from backend
  // This method now ALWAYS generates a fresh token (the backend endpoint has been updated)
  Future<void> fetchUserToken() async {
    if (_userEmail == null) {
      _userToken = null;
      notifyListeners();
      return;
    }

    try {
      // Call the backend endpoint which now always generates a fresh token
      // Reduced timeout for faster failure
      final response = await http
          .get(Uri.parse(ApiConfig.authTokenEndpoint(_userEmail!)))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _userToken = responseData['token'] as String?;

        // Store fresh token in SharedPreferences
        if (_userToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userToken', _userToken!);
          debugPrint('[AuthProvider] Fresh token generated and stored');
        }

        notifyListeners();
      } else {
        debugPrint('Error generating user token: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        _userToken = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error generating user token: $e');
      _userToken = null;
      notifyListeners();
    }
  }
}
