import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userRole; // New: To store the user's role

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userRole => _userRole; // New: Getter for user role

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
    String department = '', // Made optional with default empty string
    String designation = '', // Made optional with default empty string
  }) async {
    // Modified: added role and all onboarding parameters
    debugPrint('Attempting to register user...');
    debugPrint('  Email: $email');
    debugPrint('  First Name: $firstName');
    debugPrint('  Last Name: $lastName');
    debugPrint('  Department: $department');
    debugPrint('  Designation: $designation');

    final url = Uri.parse(
      'http://localhost:5000/api/auth/register',
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
          'role': role ?? 'user',
          'department': department,
          'designation': designation,
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 201) {
        // User registered successfully
        final responseData = json.decode(response.body);
        debugPrint('Registration successful: $responseData');

        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userEmail = email;
        _userRole = role ?? 'user';
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userRole', _userRole!);
        notifyListeners();
        return true; // Indicate success
      } else if (response.statusCode == 409) {
        debugPrint('User already exists. Attempting to log in.');
        // If user already exists, proceed as if logged in or attempt a login API call if available
        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = true;
        _userEmail = email;
        // Here, you might want to fetch the actual role of the existing user from the backend
        _userRole = role ?? 'user';
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userEmail', email);
        await prefs.setString('userRole', _userRole!);
        notifyListeners();
        return true; // Indicate success
      } else {
        // Handle other errors
        debugPrint('Registration failed with status: ${response.statusCode}');
        debugPrint('Error: ${response.body}');
        _isAuthenticated = false;
        notifyListeners();
        return false; // Indicate failure
      }
    } catch (e) {
      debugPrint('Error during registration: $e');
      _isAuthenticated = false;
      notifyListeners();
      return false; // Indicate failure
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
