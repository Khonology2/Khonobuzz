import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _setUsersAndSort(users);
  }

  DateTime _lastSignInSortKey(ManagedUser user) {
    return user.lastSignInAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _updatedSortKey(ManagedUser user) {
    return user.updatedAt ?? user.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _compareUsersForDisplay(ManagedUser a, ManagedUser b) {
    // Most recently signed-in users should always float to top for admin screens.
    final signInCompare = _lastSignInSortKey(b).compareTo(_lastSignInSortKey(a));
    if (signInCompare != 0) return signInCompare;
    return _updatedSortKey(b).compareTo(_updatedSortKey(a));
  }

  void _setUsersAndSort(List<ManagedUser> users) {
    users.sort(_compareUsersForDisplay);
    _users = users;
    _lastFetchTime = DateTime.now();
  }

  DateTime? _parseDateTimeDynamic(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    if (value is num) {
      final ts = value.toDouble();
      if (ts <= 0) return null;
      // Accept both millis and seconds.
      final millis = ts > 1e12 ? ts.toInt() : (ts * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    try {
      final candidate = (value as dynamic).toDate();
      if (candidate is DateTime) return candidate;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _selectBestOnboardingData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return {};

    QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
    DateTime bestScore = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final score =
          _parseDateTimeDynamic(data['updated_at']) ??
          _parseDateTimeDynamic(data['lastSignInAt']) ??
          _parseDateTimeDynamic(data['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (bestDoc == null || score.isAfter(bestScore)) {
        bestDoc = doc;
        bestScore = score;
      }
    }

    return bestDoc == null ? {} : Map<String, dynamic>.from(bestDoc.data());
  }

  /// Fetch users directly from Firestore - fast, no backend cold start
  Future<List<ManagedUser>?> _fetchUsersFromFirestore({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final usersSnapshot = await firestore.collection('users').get().timeout(
            timeout,
            onTimeout: () => throw Exception('Firestore timeout'),
          );

      final List<ManagedUser> managedUsers = [];
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userInfo = Map<String, dynamic>.from(userData);

        Map<String, dynamic> onboardingData = {};
        final onboardingSnapshot = await firestore
            .collection('onboarding')
            .where('user_id', isEqualTo: userDoc.id)
            .get();
        onboardingData = _selectBestOnboardingData(onboardingSnapshot.docs);

        try {
          final managed = ManagedUser.fromFirestore(
            userDoc.id,
            userInfo,
            onboardingData,
          );
          managedUsers.add(managed);
        } catch (e) {
          debugPrint('UserProvider: parse error for ${userDoc.id}: $e');
        }
      }
      return managedUsers;
    } catch (e) {
      debugPrint('UserProvider: Firestore fetch failed: $e');
      return null;
    }
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
      // Firestore first - fast, no backend cold start
      final firestoreUsers = await _fetchUsersFromFirestore(
        timeout: const Duration(seconds: 8),
      );
      if (firestoreUsers != null && firestoreUsers.isNotEmpty) {
        _setUsersAndSort(firestoreUsers);
        _hasError = false;
        _errorMessage = null;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Login prefetch Firestore failed: $e');
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
      debugPrint('Login user prefetch API failed: $e');
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
      // Firestore first - fast load, no backend cold start
      final firestoreUsers = await _fetchUsersFromFirestore(
        timeout: const Duration(seconds: 12),
      );
      if (firestoreUsers != null && firestoreUsers.isNotEmpty) {
        _setUsersAndSort(firestoreUsers);
        _hasError = false;
        _errorMessage = null;
        notifyListeners();
        _isLoading = false;
        // Refresh from API in background to sync any backend-only data
        refreshUsersInBackground();
        return;
      }
    } catch (e) {
      debugPrint('UserProvider: Firestore fetch failed: $e');
    }

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
      _users.sort(_compareUsersForDisplay);
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
      final firestoreUsers = await _fetchUsersFromFirestore(
        timeout: const Duration(seconds: 10),
      );
      if (firestoreUsers != null && firestoreUsers.isNotEmpty) {
        _setUsersAndSort(firestoreUsers);
        notifyListeners();
        return;
      }
    } catch (_) {}

    try {
      final rawUsers = await _fetchUsersPayload();
      _setUsersFromApiPayload(rawUsers);
      notifyListeners();
    } catch (e) {
      debugPrint('Background refresh failed: $e');
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
