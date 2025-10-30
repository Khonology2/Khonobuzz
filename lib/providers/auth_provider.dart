import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import '../utils/pdh_firebase.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userRole; // New: To store the user's role
  bool _userAlreadyOnboarded =
      false; // New: State to indicate if user already onboarded

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userRole => _userRole; // New: Getter for user role
  bool get userAlreadyOnboarded =>
      _userAlreadyOnboarded; // New: Getter for onboarding status

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
    _userEmail = prefs.getString('userEmail');
    _userRole = prefs.getString('userRole'); // New: Load user role
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
      'https://khonobuzz-backend.onrender.com/api/auth/register',
    ); // Your backend registration endpoint
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
          'role': role ?? 'user',
          'department': department ?? '', // Handle nullable department
          'designation': designation,
        }),
      );

      if (response.statusCode == 201) {
        // User registered successfully
        final responseData = json.decode(response.body);

        final String uid = responseData['user']?['id'] ?? '';
        if (uid.isNotEmpty) {
          final Map<String, dynamic> userData = {
            'email': email,
            'password': 'password',
            'name': '$firstName $lastName',
            'role': role ?? 'user',
            'status': 'Pending',
            'created_at': DateTime.now().toUtc(),
            'updated_at': DateTime.now().toUtc(),
          };
          final Map<String, dynamic> onboardingData = {
            'user_id': uid,
            'email': email,
            'name': firstName,
            'surname': lastName,
            'department': department ?? '',
            'designation': designation,
            'first_valid': DateTime.utc(2025, 9, 25),
            'inserted_by': email,
            'last_valid': DateTime.utc(2039, 12, 31),
            'onboarding_id': uid,
            'status_id': '',
            'updated_by': email,
            'created_at': DateTime.now().toUtc(),
            'updated_at': DateTime.now().toUtc(),
          };
          await syncUserToPDH(userData, onboardingData, uid).catchError((_) {});
        }

        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userEmail = email;
        _userRole = role ?? 'user';
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userRole', _userRole!);
        _userAlreadyOnboarded =
            false; // Reset onboarding status for new registration
        notifyListeners();
        return true; // Indicate success
      } else if (response.statusCode == 409) {
        // If user already exists, proceed as if logged in or attempt a login API call if available
        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userEmail = email;
        // Here, you might want to fetch the actual role of the existing user from the backend
        _userRole = role ?? 'user';
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userRole', _userRole!);
        _userAlreadyOnboarded = true; // Set onboarding status to true
        notifyListeners();
        return true; // Indicate success
      } else {
        // Handle other errors
        _isAuthenticated = false;
        _userAlreadyOnboarded = false; // Reset onboarding status on failure
        notifyListeners();
        return false; // Indicate failure
      }
    } catch (e) {
      _isAuthenticated = false;
      _userAlreadyOnboarded = false; // Reset onboarding status on error
      notifyListeners();
      return false; // Indicate failure
    }
  }

  Future<bool> manualLogin(String email) async {
    // Removed password parameter

    final url = Uri.parse(
      'https://khonobuzz-backend.onrender.com/api/auth/login',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userEmail = responseData['user']['email'];
        _userRole = responseData['user']['role'];
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', _userEmail!);
        await prefs.setString('userRole', _userRole!);
        notifyListeners();
        return true;
      } else {
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = false;
    _userEmail = null;
    _userRole = null; // New: Clear user role
    await prefs.remove('isAuthenticated');
    await prefs.remove('userEmail');
    await prefs.remove('userRole'); // New: Remove user role
    notifyListeners();
  }
}
