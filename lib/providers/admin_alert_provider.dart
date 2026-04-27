import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/admin_alert.dart';
import '../services/admin_alert_service.dart';

class AdminAlertProvider extends ChangeNotifier {
  static const Duration _pollInterval = Duration(seconds: 12);

  List<AdminAlert> _alerts = const [];
  final Set<String> _knownIds = <String>{};
  final List<AdminAlert> _newAlertsQueue = <AdminAlert>[];
  Timer? _pollTimer;
  String _currentRole = '';
  String _currentUserEmail = '';
  bool _isFetching = false;
  bool _hasBootstrapped = false;

  List<AdminAlert> get alerts => _alerts;
  int get unreadCount => _alerts.length;

  Future<void> start(String role, {String userEmail = ''}) async {
    final normalizedRole = role.trim().toLowerCase();
    final normalizedEmail = userEmail.trim().toLowerCase();
    if (normalizedRole.isEmpty) {
      stop();
      return;
    }

    if (_currentRole == normalizedRole &&
        _currentUserEmail == normalizedEmail &&
        _pollTimer != null) {
      return;
    }

    _currentRole = normalizedRole;
    _currentUserEmail = normalizedEmail;
    _hasBootstrapped = false;
    _alerts = const [];
    _knownIds.clear();
    _newAlertsQueue.clear();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _fetchLatest();
    });
    _fetchLatest();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _currentRole = '';
    _currentUserEmail = '';
    _hasBootstrapped = false;
    _isFetching = false;
    _alerts = const [];
    _knownIds.clear();
    _newAlertsQueue.clear();
    notifyListeners();
  }

  List<AdminAlert> takeNewAlerts() {
    if (_newAlertsQueue.isEmpty) {
      return const [];
    }
    final items = List<AdminAlert>.from(_newAlertsQueue);
    _newAlertsQueue.clear();
    return items;
  }

  Future<void> clearAllAlerts() async {
    if (_currentRole.isEmpty || _currentUserEmail.isEmpty) {
      return;
    }
    await AdminAlertService.clearAlertsForUser(
      role: _currentRole,
      userEmail: _currentUserEmail,
    );
    _alerts = const [];
    _knownIds.clear();
    _newAlertsQueue.clear();
    notifyListeners();
    await _fetchLatest();
  }

  Future<void> _fetchLatest() async {
    if (_isFetching || _currentRole.isEmpty) {
      return;
    }
    _isFetching = true;
    try {
      final fetched = await AdminAlertService.fetchAlertsForRole(
        _currentRole,
        userEmail: _currentUserEmail,
        limit: _currentRole == 'staff' ? 30 : 60,
      );
      final newItems = <AdminAlert>[];
      for (final alert in fetched) {
        if (_knownIds.add(alert.id)) {
          if (_hasBootstrapped) {
            newItems.add(alert);
          }
        }
      }

      if (newItems.isNotEmpty) {
        newItems.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _newAlertsQueue.addAll(newItems);
      }

      _alerts = fetched;
      _hasBootstrapped = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AdminAlertProvider] fetch failed: $e');
    } finally {
      _isFetching = false;
    }
  }
}
