import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:async'; // Import for TimeoutException
import '../utils/pdh_firebase.dart' show syncUserToPDH, syncUserToSkillsHeatmap;
import '../config/api_config.dart';
import '../services/modules_ping_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _fallbackBackendBaseUrl = String.fromEnvironment(
    'BACKEND_FALLBACK_URL',
    defaultValue: 'https://khonobuzz-backend-ac0j.onrender.com',
  );

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
  String? _userThemePreference; // Preferred app theme: light | dark
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
  String? get userThemePreference => _userThemePreference;
  bool get isSpecialSession => _isSpecialSession; // Getter for special session
  Map<String, dynamic>? get cachedProfileData =>
      _cachedProfileData; // Getter for cached profile data

  AuthProvider() {
    _loadAuthState();
  }

  /// Call when manual login screen is shown to wake up cold backend (e.g. Render) so login is faster.
  static void warmUpBackendForLogin() {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/health');
      http.get(uri).timeout(const Duration(seconds: 20)).then((_) {}, onError: (_) {});
    } catch (_) {}
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
        await Future.delayed(const Duration(milliseconds: 400));
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

  Future<http.Response> _getWithTimeoutAndRetry(
    Uri url, {
    Map<String, String>? headers,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    http.Response? lastResponse;
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final attemptStart = DateTime.now().millisecondsSinceEpoch;
      try {
        final response = await http
            .get(url, headers: headers)
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
          '[AuthProvider] GET ${url.path} attempt ${attempt + 1} '
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
          '[AuthProvider] GET ${url.path} attempt ${attempt + 1} '
          'timed out after ${elapsed}ms: ${e.message}',
        );
      } catch (e) {
        lastError = e;
        final elapsed = DateTime.now().millisecondsSinceEpoch - attemptStart;
        debugPrint(
          '[AuthProvider] GET ${url.path} attempt ${attempt + 1} '
          'failed after ${elapsed}ms: $e',
        );
      }
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 600));
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

  List<Uri> _candidateAuthLoginUris() {
    final primary = Uri.parse(ApiConfig.authLoginEndpoint);
    final uris = <Uri>[primary];
    if (_fallbackBackendBaseUrl.isNotEmpty) {
      final fallback = Uri.parse(
        '${_fallbackBackendBaseUrl.replaceAll(RegExp(r"/+$"), "")}/api/auth/login',
      );
      if (fallback.toString() != primary.toString()) {
        uris.add(fallback);
      }
    }
    return uris;
  }

  List<Uri> _candidateUserLookupUris(String email) {
    final primary = Uri.parse(ApiConfig.userByEmailEndpoint(email));
    final uris = <Uri>[primary];
    if (_fallbackBackendBaseUrl.isNotEmpty) {
      final fallback = Uri.parse(
        '${_fallbackBackendBaseUrl.replaceAll(RegExp(r"/+$"), "")}/api/users/by-email?email=${Uri.encodeComponent(email)}',
      );
      if (fallback.toString() != primary.toString()) {
        uris.add(fallback);
      }
    }
    return uris;
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
    _userThemePreference = prefs.getString('userThemePreference');
    _isSpecialSession = prefs.getBool('_spSess') ?? false;

    // Only keep profile image if it clearly belongs to the stored user (prevents showing another user's pic)
    if (_userEmail != null && (_userProfileImageUrl != null || _userProfilePublicId != null)) {
      final cur = _userEmail!.trim().toLowerCase();
      final curEnc = cur.replaceAll('@', '%40');
      final urlOk = _userProfileImageUrl == null ||
          _userProfileImageUrl!.toLowerCase().contains(cur) ||
          _userProfileImageUrl!.contains(curEnc);
      final idOk = _userProfilePublicId == null ||
          _userProfilePublicId!.toLowerCase().contains(cur) ||
          _userProfilePublicId!.contains(curEnc);
      if (!urlOk || !idOk) {
        _userProfileImageUrl = null;
        _userProfilePublicId = null;
        await Future.wait([
          prefs.remove('userProfileImageUrl'),
          prefs.remove('userProfilePublicId'),
        ]);
      }
    }

    debugPrint(
      '[AuthProvider] _loadAuthState - userProfileImageUrl: $_userProfileImageUrl',
    );
    debugPrint(
      '[AuthProvider] _loadAuthState - userProfilePublicId: $_userProfilePublicId',
    );

    if (_isAuthenticated) {
      ModulesPingService.start();
    }

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
        _userThemePreference =
            (userPayload['themePreference'] as String?)?.trim().toLowerCase();
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
          if (_userThemePreference != null && _userThemePreference!.isNotEmpty)
            prefs.setString('userThemePreference', _userThemePreference!),
          if (tokenFromResponse != null)
            prefs.setString('userToken', tokenFromResponse),
        ]);

        if (tokenFromResponse != null) {
          _userToken = tokenFromResponse;
        }

        notifyListeners();

        ModulesPingService.start();

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
    final normalizedEmail = email.trim().toLowerCase();

    // Clear previous user's profile and cache as soon as login is attempted so we never show their data
    _cachedProfileData = null;
    _userProfileImageUrl = null;
    _userProfilePublicId = null;
    _userThemePreference = null;
    final prefsForClear = await SharedPreferences.getInstance();
    await Future.wait([
      prefsForClear.remove('userProfileImageUrl'),
      prefsForClear.remove('userProfilePublicId'),
    ]);
    notifyListeners();

    try {
      final start = DateTime.now().millisecondsSinceEpoch;
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (isSpecialAccess) {
        headers['X-Session-Type'] = 'special';
      }

      http.Response? response;
      Object? lastError;
      const int rounds = 2;
      for (int round = 1; round <= rounds && response == null; round++) {
        for (final url in _candidateAuthLoginUris()) {
          try {
            debugPrint('[AuthProvider] Trying login endpoint (round $round/$rounds): $url');
            final candidateResponse = await _postWithTimeoutAndRetry(
              url,
              headers: headers,
              body: json.encode({'email': normalizedEmail}),
              maxRetries: 1,
              timeout: const Duration(seconds: 35),
            );
            if (candidateResponse.statusCode < 500) {
              response = candidateResponse;
              break;
            }
            lastError = Exception(
              'status ${candidateResponse.statusCode} from $url',
            );
          } catch (e) {
            lastError = e;
            debugPrint('[AuthProvider] Login endpoint failed ($url): $e');
            continue;
          }
        }
        if (response == null && round < rounds) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (response == null) {
        throw Exception(lastError?.toString() ?? 'All login endpoints failed');
      }
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

        // Clear previous user's cached data and profile image to prevent showing another user's profile
        _cachedProfileData = null;
        _userProfileImageUrl = null;
        _userProfilePublicId = null;

        _isAuthenticated = true;
        _isSpecialSession = isSpecialAccess;
        _userEmail = userPayload['email'] as String;
        _userRole = isSpecialAccess
            ? 'Admin'
            : (userPayload['role'] ?? 'Staff');
        _userThemePreference =
            (userPayload['themePreference'] as String?)?.trim().toLowerCase();
        _initialScreenIndex = 9;
        _currentScreenIndex = 9;

        // Extract module access from user payload if available (faster than separate API call)
        final moduleAccessRaw = userPayload['moduleAccess'] as String?;
        final moduleAccessRoleRaw = userPayload['moduleAccessRole'] as String?;
        _userModuleAccess = _deriveModuleAccessFromRole(
          moduleAccessRaw,
          moduleAccessRoleRaw,
        );

        // Extract profile image data from login response (only for this user)
        debugPrint('[AuthProvider] Login response userPayload: $userPayload');
        _userProfileImageUrl = userPayload['profileImageUrl'] as String?;
        _userProfilePublicId = userPayload['profileImagePublicId'] as String?;
        // Defensive: if profile URL/publicId clearly belong to another user (e.g. contain different email), clear them
        if (_userEmail != null && (_userProfileImageUrl != null || _userProfilePublicId != null)) {
          final cur = _userEmail!.trim().toLowerCase();
          final curEnc = cur.replaceAll('@', '%40');
          final urlOk = _userProfileImageUrl == null ||
              _userProfileImageUrl!.toLowerCase().contains(cur) ||
              _userProfileImageUrl!.contains(curEnc);
          final idOk = _userProfilePublicId == null ||
              _userProfilePublicId!.toLowerCase().contains(cur) ||
              _userProfilePublicId!.contains(curEnc);
          if (!urlOk || !idOk) {
            _userProfileImageUrl = null;
            _userProfilePublicId = null;
          }
        }
        debugPrint(
          '[AuthProvider] Extracted profileImageUrl: $_userProfileImageUrl',
        );
        debugPrint(
          '[AuthProvider] Extracted profileImagePublicId: $_userProfilePublicId',
        );

        // Batch all SharedPreferences writes (clear old profile image if not set for new user)
        final writeTasks = <Future>[
          prefs.setBool('isAuthenticated', true),
          prefs.setString('userEmail', _userEmail!),
          prefs.setString('userRole', _userRole!),
          prefs.setInt('initialScreenIndex', 9),
          prefs.setInt('currentScreenIndex', 9),
          if (_userProfileImageUrl != null)
            prefs.setString('userProfileImageUrl', _userProfileImageUrl!)
          else
            prefs.remove('userProfileImageUrl'),
          if (_userProfilePublicId != null)
            prefs.setString('userProfilePublicId', _userProfilePublicId!)
          else
            prefs.remove('userProfilePublicId'),
          if (_userModuleAccess != null)
            prefs.setString('userModuleAccess', _userModuleAccess!),
          if (_userThemePreference != null && _userThemePreference!.isNotEmpty)
            prefs.setString('userThemePreference', _userThemePreference!)
          else
            prefs.remove('userThemePreference'),
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
      } else if (!isSpecialAccess && response.statusCode >= 500) {
        final success = await _attemptFallbackLogin(email);
        if (success) {
          return true;
        }
        _isAuthenticated = false;
        notifyListeners();
        return false;
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
              e.toString().contains('timeout') ||
              e.toString().contains('TimeoutException') ||
              e.toString().contains('XMLHttpRequest error') ||
              e.toString().contains('ClientException') ||
              e.toString().contains('net::ERR_FAILED') ||
              e.toString().contains('CORS'))) {
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
    ModulesPingService.start();
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

        final fetchedEmail = (userMap['email'] as String? ?? '').trim().toLowerCase();
        final currentEmail = email.trim().toLowerCase();
        if (fetchedEmail != currentEmail) {
          debugPrint('[AuthProvider] Ignoring profile data: fetched email does not match current user');
          return;
        }

        // Update AuthProvider with profile image data (clear when user has no image so we never show another user's)
        final profileImageUrl = userMap['profileImageUrl'] as String?;
        final profileImagePublicId = userMap['profileImagePublicId'] as String?;
        final hasImage = (profileImageUrl ?? '').trim().isNotEmpty || (profileImagePublicId ?? '').trim().isNotEmpty;
        if (hasImage) {
          await updateUserProfileImage(profileImageUrl, profileImagePublicId);
          debugPrint('[AuthProvider] Profile data prefetched successfully');
        } else {
          await updateUserProfileImage(null, null);
        }

        // Store other profile data for potential future use (only for this user; already validated email match)
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
    try {
      http.Response? userCheckResponse;
      Object? lastError;
      const int rounds = 2;
      for (int round = 1; round <= rounds && userCheckResponse == null; round++) {
        for (final userCheckUrl in _candidateUserLookupUris(email)) {
          try {
            debugPrint(
              '[AuthProvider] Trying user lookup endpoint (round $round/$rounds): $userCheckUrl',
            );
            final candidateResponse = await _getWithTimeoutAndRetry(
              userCheckUrl,
              maxRetries: 2,
              timeout: const Duration(seconds: 45),
            );
            if (candidateResponse.statusCode < 500) {
              userCheckResponse = candidateResponse;
              break;
            }
            lastError = Exception(
              'status ${candidateResponse.statusCode} from $userCheckUrl',
            );
          } catch (e) {
            lastError = e;
            debugPrint('[AuthProvider] User lookup endpoint failed ($userCheckUrl): $e');
            continue;
          }
        }
        if (userCheckResponse == null && round < rounds) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (userCheckResponse == null) {
        throw Exception(lastError?.toString() ?? 'All user lookup endpoints failed');
      }

      if (userCheckResponse.statusCode == 200) {
        final usersData = json.decode(userCheckResponse.body);
        final foundUser = usersData['user'] as Map<String, dynamic>?;

        if (foundUser != null) {
          final prefs = await SharedPreferences.getInstance();
          _cachedProfileData = null;
          _userProfileImageUrl = null;
          _userProfilePublicId = null;
          _isAuthenticated = true;
          _userEmail = foundUser['email'] ?? email;
          _userRole = foundUser['role'] ?? 'Staff';
          _userThemePreference =
              (foundUser['themePreference'] as String?)?.trim().toLowerCase();
          _initialScreenIndex = 9;
          _currentScreenIndex = 9;

          final moduleAccessRaw = foundUser['moduleAccess'] as String?;
          final moduleAccessRoleRaw = foundUser['moduleAccessRole'] as String?;
          _userModuleAccess = _deriveModuleAccessFromRole(
            moduleAccessRaw,
            moduleAccessRoleRaw,
          );
          _userProfileImageUrl = foundUser['profileImageUrl'] as String?;
          _userProfilePublicId = foundUser['profileImagePublicId'] as String?;

          final prefsWrites = <Future>[
            prefs.setBool('isAuthenticated', true),
            prefs.setString('userEmail', _userEmail!),
            prefs.setString('userRole', _userRole!),
            prefs.setInt('initialScreenIndex', 9),
            prefs.setInt('currentScreenIndex', 9),
          ];
          if (_userModuleAccess != null) {
            prefsWrites.add(prefs.setString('userModuleAccess', _userModuleAccess!));
          }
          if (_userProfileImageUrl != null) {
            prefsWrites.add(prefs.setString('userProfileImageUrl', _userProfileImageUrl!));
          } else {
            prefsWrites.add(prefs.remove('userProfileImageUrl'));
          }
          if (_userProfilePublicId != null) {
            prefsWrites.add(prefs.setString('userProfilePublicId', _userProfilePublicId!));
          } else {
            prefsWrites.add(prefs.remove('userProfilePublicId'));
          }
          if (_userThemePreference != null && _userThemePreference!.isNotEmpty) {
            prefsWrites.add(
              prefs.setString('userThemePreference', _userThemePreference!),
            );
          } else {
            prefsWrites.add(prefs.remove('userThemePreference'));
          }
          await Future.wait(prefsWrites);

          notifyListeners();

          ModulesPingService.start();

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
    ModulesPingService.stop();
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
    _userThemePreference = null;
    _isSpecialSession = false;
    _cachedProfileData = null;
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
      prefs.remove('userThemePreference'),
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

  // Update user's profile image (pass null or empty to clear)
  Future<void> updateUserProfileImage(
    String? imageUrl,
    String? publicId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    _userProfileImageUrl = (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null;
    _userProfilePublicId = (publicId != null && publicId.isNotEmpty) ? publicId : null;
    await Future.wait([
      _userProfileImageUrl != null
          ? prefs.setString('userProfileImageUrl', _userProfileImageUrl!)
          : prefs.remove('userProfileImageUrl'),
      _userProfilePublicId != null
          ? prefs.setString('userProfilePublicId', _userProfilePublicId!)
          : prefs.remove('userProfilePublicId'),
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
  Future<void> fetchUserToken({String? themePreference}) async {
    if (_userEmail == null) {
      _userToken = null;
      notifyListeners();
      return;
    }

    try {
      // Call the backend endpoint which now always generates a fresh token
      // Reduced timeout for faster failure
      final normalizedTheme = (themePreference ?? _userThemePreference ?? '')
          .trim()
          .toLowerCase();
      final response = await http
          .get(
            Uri.parse(
              ApiConfig.authTokenEndpoint(
                _userEmail!,
                theme: normalizedTheme.isEmpty ? null : normalizedTheme,
              ),
            ),
          )
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

  Future<void> syncThemePreferenceAndRefreshToken(String themePreference) async {
    final normalizedTheme = themePreference.trim().toLowerCase();
    if (_userEmail == null || _userEmail!.isEmpty) {
      _userThemePreference = normalizedTheme;
      notifyListeners();
      return;
    }
    if (normalizedTheme != 'light' && normalizedTheme != 'dark') {
      return;
    }

    _userThemePreference = normalizedTheme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userThemePreference', normalizedTheme);

    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/admin/users/$_userEmail/profile'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'themePreference': normalizedTheme}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = (data is Map<String, dynamic>) ? data['token'] as String? : null;
        if (token != null && token.isNotEmpty) {
          _userToken = token;
          await prefs.setString('userToken', token);
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] Theme sync endpoint failed, fallback token refresh: $e');
    }

    await fetchUserToken(themePreference: normalizedTheme);
  }
}
