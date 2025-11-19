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

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _userEmail = prefs.getString('userEmail');
    _userRole = prefs.getString('userRole'); // New: Load user role
    _initialScreenIndex = prefs.getInt(
      'initialScreenIndex',
    ); // Load initial screen index
    _currentScreenIndex = prefs.getInt(
      'currentScreenIndex',
    ); // Load current screen index for refresh persistence
    _userToken = prefs.getString('userToken'); // Load user token
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

    final url = Uri.parse(
      ApiConfig.authRegisterEndpoint,
    ); // Your backend registration endpoint
    
    // Debug logging
    debugPrint('[AuthProvider] Attempting to register/login with URL: $url');
    debugPrint('[AuthProvider] Backend base URL: ${ApiConfig.baseUrl}');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password':
              'password', // Placeholder: You might want a proper password or remove this if registration is passwordless
          'name': '$firstName $lastName',
          'firstName': firstName, // Added to match Pydantic model
          'lastName': lastName, // Added to match Pydantic model
          'role': role ?? 'Staff',
          'department': department ?? '', // Handle nullable department
          'designation': designation,
        }),
      );
      
      debugPrint('[AuthProvider] Response status: ${response.statusCode}');
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

          try {
            await syncUserToPDH(userData, onboardingData, uid);
          } catch (e) {
            debugPrint(
              'Failed to sync new user to PDH during registration: $e',
            );
            // This error is logged for debugging, but we don't block the user
            // from proceeding since the main registration was successful.
          }
          try {
            await syncUserToSkillsHeatmap(userData, onboardingData, uid);
          } catch (e) {
            debugPrint(
              'Failed to sync new user to Skills Heatmap during registration: $e',
            );
            // This error is logged for debugging, but we don't block the user
            // from proceeding since the main registration was successful.
          }
        }

        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userEmail = email;
        _userRole = userPayload['role'] ?? role ?? 'Staff';
        // Store token if present in response
        if (tokenFromResponse != null) {
          _userToken = tokenFromResponse;
          await prefs.setString('userToken', _userToken!);
        }
        // Both Staff and Admin users navigate to Modules screen (index 9) on login
        _initialScreenIndex = 9;
        _currentScreenIndex = 9;
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userRole', _userRole!);
        await prefs.setInt(
          'initialScreenIndex',
          9,
        ); // Store initial screen index
        await prefs.setInt(
          'currentScreenIndex',
          9,
        ); // Store current screen index for refresh
        _userAlreadyOnboarded =
            false; // Reset onboarding status for new registration
        notifyListeners();
        // Fetch module access after login
        fetchCurrentUserModuleAccess();
        // Fetch token if not present
        if (_userToken == null) {
          await fetchUserToken();
        }
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

  Future<bool> manualLogin(String email) async {
    // Removed password parameter

    final url = Uri.parse(ApiConfig.authLoginEndpoint);
    
    // Debug logging
    debugPrint('[AuthProvider] Attempting manual login with URL: $url');
    debugPrint('[AuthProvider] Backend base URL: ${ApiConfig.baseUrl}');
    
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('[AuthProvider] Login request timed out');
              throw TimeoutException(
                'Login request timed out. Please check your internet connection and try again.',
              );
            },
          );
      
      debugPrint('[AuthProvider] Login response status: ${response.statusCode}');
      debugPrint('[AuthProvider] Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        final userPayload = responseData['user'] as Map<String, dynamic>? ?? {};
        _userEmail = userPayload['email'];
        _userRole = userPayload['role'] ?? 'Staff';
        // Store token if present in response
        if (responseData.containsKey('token')) {
          _userToken = responseData['token'] as String?;
          await prefs.setString('userToken', _userToken!);
        }
        // Both Staff and Admin users navigate to Modules screen (index 9) on login
        _initialScreenIndex = 9;
        _currentScreenIndex = 9;
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', _userEmail!);
        await prefs.setString('userRole', _userRole!);
        await prefs.setInt(
          'initialScreenIndex',
          9,
        ); // Store initial screen index
        await prefs.setInt(
          'currentScreenIndex',
          9,
        ); // Store current screen index for refresh
        notifyListeners();
        // Fetch module access after login
        fetchCurrentUserModuleAccess();
        // Fetch token if not present
        if (_userToken == null) {
          await fetchUserToken();
        }
        return true;
      } else if (response.statusCode == 403) {
        // User account is not active (Pending status)
        final responseData = json.decode(response.body);
        final errorMessage = responseData['error'] as String? ?? 
            'Your account is pending approval. Please wait for admin activation.';
        debugPrint('Login rejected: $errorMessage');
        _isAuthenticated = false;
        notifyListeners();
        // Store error message for display (you can access this via a getter if needed)
        throw Exception(errorMessage);
      } else if (response.statusCode == 404 ||
          response.statusCode == 401) {
        // User not found or unauthorized - but still allow login if email exists in our system
        // Check if user exists by attempting to fetch user data
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
    } on TimeoutException catch (e) {
      debugPrint('Manual login timeout: $e');
      final success = await _attemptFallbackLogin(email);
      if (success) {
        return true;
      }
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Manual login error: $e');
      final success = await _attemptFallbackLogin(email);
      if (success) {
        return true;
      }
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _attemptFallbackLogin(String email) async {
    final userCheckUrl = Uri.parse(ApiConfig.usersEndpoint);
    try {
      final userCheckResponse = await http
          .get(userCheckUrl)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

      if (userCheckResponse.statusCode == 200) {
        final usersData = json.decode(userCheckResponse.body);
        final users = (usersData['users'] as List<dynamic>? ?? []);
        Map<String, dynamic>? foundUser;
        try {
          foundUser =
              users.firstWhere(
                    (u) =>
                        (u as Map<String, dynamic>)['email']
                            ?.toString()
                            .toLowerCase() ==
                        email.toLowerCase(),
                  )
                  as Map<String, dynamic>?;
        } catch (_) {
          foundUser = null;
        }

        if (foundUser != null) {
          // Check user status - reject if not Active
          final userStatus = foundUser['status']?.toString() ?? 'Pending';
          if (userStatus != 'Active') {
            debugPrint('Fallback login rejected: User status is $userStatus');
            _isAuthenticated = false;
            notifyListeners();
            return false;
          }
          
          final prefs = await SharedPreferences.getInstance();
          _isAuthenticated = true;
          _userEmail = foundUser['email'] ?? email;
          _userRole = foundUser['role'] ?? 'Staff';
          // Both Staff and Admin users navigate to Modules screen (index 9) on login
          _initialScreenIndex = 9;
          _currentScreenIndex = 9;
          await prefs.setBool('isAuthenticated', true);
          await prefs.setString('userEmail', _userEmail!);
          await prefs.setString('userRole', _userRole!);
          await prefs.setInt('initialScreenIndex', 9);
          await prefs.setInt(
            'currentScreenIndex',
            9,
          ); // Store current screen index for refresh
          notifyListeners();
          // Fetch module access after fallback login
          fetchCurrentUserModuleAccess();
          // Fetch token after fallback login
          await fetchUserToken();
          return true;
        }
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
    _userRole = null; // New: Clear user role
    _initialScreenIndex = null; // Clear initial screen index
    _currentScreenIndex = null; // Clear current screen index
    _userModuleAccess = null; // Clear module access
    _userToken = null; // Clear user token
    await prefs.remove('isAuthenticated');
    await prefs.remove('userEmail');
    await prefs.remove('userRole'); // New: Remove user role
    await prefs.remove('initialScreenIndex'); // Remove initial screen index
    await prefs.remove('currentScreenIndex'); // Remove current screen index
    await prefs.remove('userToken'); // Remove user token
    notifyListeners();
  }

  void clearInitialScreenIndex() {
    _initialScreenIndex = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('initialScreenIndex');
    });
    notifyListeners();
  }

  // Save current screen index for refresh persistence
  Future<void> saveCurrentScreenIndex(int index) async {
    _currentScreenIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentScreenIndex', index);
    notifyListeners();
  }

  // Fetch current user's module access from API
  Future<void> fetchCurrentUserModuleAccess() async {
    if (_userEmail == null) {
      _userModuleAccess = null;
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(Uri.parse(ApiConfig.usersEndpoint));

      if (response.statusCode == 200) {
        final usersData = json.decode(response.body);
        final users = (usersData['users'] as List<dynamic>? ?? []);

        try {
          final foundUser =
              users.firstWhere(
                    (u) =>
                        (u as Map<String, dynamic>)['email']
                            ?.toString()
                            .toLowerCase() ==
                        _userEmail!.toLowerCase(),
                  )
                  as Map<String, dynamic>?;

          _userModuleAccess = foundUser?['moduleAccess'] as String?;
          notifyListeners();
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
  bool hasModuleAccess(String moduleName) {
    if (_userModuleAccess == null || _userModuleAccess!.isEmpty) {
      return false;
    }
    final accessList = _userModuleAccess!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return accessList.contains(moduleName);
  }

  // Fetch user token from backend
  Future<void> fetchUserToken() async {
    if (_userEmail == null) {
      _userToken = null;
      notifyListeners();
      return;
    }

    try {
      final response = await http
          .get(Uri.parse(ApiConfig.authTokenEndpoint(_userEmail!)))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _userToken = responseData['token'] as String?;

        // Store token in SharedPreferences
        if (_userToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userToken', _userToken!);
        }

        notifyListeners();
      } else {
        debugPrint('Error fetching user token: ${response.statusCode}');
        _userToken = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user token: $e');
      _userToken = null;
      notifyListeners();
    }
  }
}
