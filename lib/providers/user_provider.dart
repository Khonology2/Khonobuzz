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

  void _setUsersFromApiPayload(List<dynamic> rawUsers) {
    final usersData = rawUsers.whereType<Map<String, dynamic>>().toList();
    final users = usersData
        .map((user) => ManagedUser.fromApi(user))
        .toList(growable: false);

    users.sort((a, b) {
      final aKey =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bKey =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bKey.compareTo(aKey);
    });

    _users = users;
    _lastFetchTime = DateTime.now();
  }

  Future<List<dynamic>> _fetchUsersPayload({
    Duration timeout = const Duration(seconds: 90),
    int retries = 2,
  }) async {
    // Render free tier cold start can take 50+ seconds; use 90s timeout and retries
    Exception? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await http
            .get(Uri.parse(ApiConfig.usersEndpoint))
            .timeout(
              timeout,
              onTimeout: () {
                throw Exception(
                  'Request timeout. The server may be waking up—please try again.',
                );
              },
            );

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch users: ${response.statusCode}');
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['users'] as List<dynamic>? ?? const [];
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < retries) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
    throw lastError ?? Exception('Failed to fetch users');
  }

  Future<void> prefetchUsersForLogin({bool forceRefresh = false}) async {
    if (!forceRefresh && isCacheValid && _users.isNotEmpty) {
      return;
    }

    if (_isLoading) {
      return;
    }

    try {
      final rawUsers = await _fetchUsersPayload(
        timeout: const Duration(seconds: 15),
      );
      _setUsersFromApiPayload(rawUsers);
      _hasError = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Login user prefetch failed: $e');
    }
  }

  Future<void> fetchUsers({bool forceRefresh = false}) async {
    // Stale-while-revalidate: if we have cached data, show it and refresh in background
    // unless a hard refresh is explicitly requested.
    if (!forceRefresh && _users.isNotEmpty) {
      refreshUsersInBackground();
      return;
    }

    // Return cached data if available and valid, unless force refresh (only when empty - handled above)
    if (!forceRefresh && isCacheValid) {
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
      final rawUsers = await _fetchUsersPayload();
      _setUsersFromApiPayload(rawUsers);
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

  // Update a single user in the cache. Set updatedAt to now so the edited user moves to the top.
  void updateUser(ManagedUser updatedUser) {
    final index = _users.indexWhere((u) => u.id == updatedUser.id);
    if (index != -1) {
      final bumped = updatedUser.copyWith(updatedAt: DateTime.now());
      _users[index] = bumped;
      // Re-sort by updatedAt/createdAt descending so most recently edited is at top
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
      final rawUsers = await _fetchUsersPayload();
      _setUsersFromApiPayload(rawUsers);
      notifyListeners();
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
    if (_users.isNotEmpty) {
      return _users
          .map((user) => user.email.trim())
          .where((email) => email.isNotEmpty)
          .toList(growable: false);
    }

    try {
      await prefetchUsersForLogin();
      if (_users.isNotEmpty) {
        return _users
            .map((user) => user.email.trim())
            .where((email) => email.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Silent error handling
    }
    return [];
  }
}
