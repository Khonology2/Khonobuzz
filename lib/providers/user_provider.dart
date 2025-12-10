import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/managed_user.dart';
import '../config/api_config.dart';

class UserProvider extends ChangeNotifier {
  List<ManagedUser> _users = [];
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  List<ManagedUser> get users => _users;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  bool get hasCachedData => _users.isNotEmpty && _lastFetchTime != null;

  // Check if cache is still valid
  bool get isCacheValid {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidDuration;
  }

  UserProvider() {
    // Optionally load cached data on initialization
    _loadCachedData();
  }

  // Load cached data from memory (already loaded users)
  void _loadCachedData() {
    // If we have cached data that's still valid, use it
    if (isCacheValid && _users.isNotEmpty) {
      return;
    }
  }

  Future<void> fetchUsers({bool forceRefresh = false}) async {
    // Return cached data if available and valid, unless force refresh
    if (!forceRefresh && isCacheValid && _users.isNotEmpty) {
      return;
    }

    // If already loading, don't start another request
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(ApiConfig.usersEndpoint))
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch users: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final usersData = (decoded['users'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final users = usersData
          .map((user) => ManagedUser.fromApi(user))
          .toList(growable: false);

      // Sort by updatedAt/createdAt
      users.sort((a, b) {
        final aKey =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bKey =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bKey.compareTo(aKey);
      });

      _users = users;
      _lastFetchTime = DateTime.now();
      _hasError = false;
      _errorMessage = null;
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      debugPrint('Error fetching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update a single user in the cache
  void updateUser(ManagedUser updatedUser) {
    final index = _users.indexWhere((u) => u.id == updatedUser.id);
    if (index != -1) {
      _users[index] = updatedUser;
      // Re-sort after update
      _users.sort((a, b) {
        final aKey =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bKey =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bKey.compareTo(aKey);
      });
      notifyListeners();
    }
  }

  // Remove a single user from the cache
  void removeUser(String userId) {
    final initialLength = _users.length;
    _users.removeWhere((u) => u.id == userId);
    if (_users.length < initialLength) {
      notifyListeners();
    }
  }

  // Remove multiple users from the cache
  void removeUsers(List<String> userIds) {
    final initialLength = _users.length;
    _users.removeWhere((u) => userIds.contains(u.id));
    if (_users.length < initialLength) {
      notifyListeners();
    }
  }

  // Refresh users in background (silent refresh)
  Future<void> refreshUsersInBackground() async {
    if (_isLoading) return;

    try {
      final response = await http
          .get(Uri.parse(ApiConfig.usersEndpoint))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final usersData = (decoded['users'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        final users = usersData
            .map((user) => ManagedUser.fromApi(user))
            .toList(growable: false);

        users.sort((a, b) {
          final aKey =
              a.updatedAt ??
              a.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bKey =
              b.updatedAt ??
              b.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bKey.compareTo(aKey);
        });

        _users = users;
        _lastFetchTime = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Background refresh failed: $e');
      // Don't update error state for background refresh
    }
  }

  // Clear cache
  void clearCache() {
    _users = [];
    _lastFetchTime = null;
    notifyListeners();
  }

  // Fetch all user emails for selection (silent operation)
  Future<List<String>> fetchAllUserEmails() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.usersEndpoint))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final usersData = (decoded['users'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        return usersData
            .map((user) => (user['email'] as String? ?? '').trim())
            .where((email) => email.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Silent error handling
    }
    return [];
  }
}
