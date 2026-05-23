import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user choice of light vs dark theme.
/// Callers should pass [initialMode] from prefs (e.g. in [main]) so startup
/// does not race with async SharedPreferences and overwrite a user toggle.
class ThemeModeProvider extends ChangeNotifier {
  static const prefsKey = 'app_theme_mode';

  ThemeMode _themeMode;
  Future<void> Function(String themePreference)? _themeSyncCallback;

  ThemeModeProvider({ThemeMode initialMode = ThemeMode.dark})
      : _themeMode = initialMode;

  ThemeMode get themeMode => _themeMode;

  bool get isLight => _themeMode == ThemeMode.light;

  void setThemeSyncCallback(Future<void> Function(String)? callback) {
    _themeSyncCallback = callback;
  }

  Future<void> setThemeMode(
    ThemeMode mode, {
    bool persist = true,
    bool syncBackend = true,
  }) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKey,
        _themeMode == ThemeMode.light ? 'light' : 'dark',
      );
    }
    if (syncBackend && _themeSyncCallback != null) {
      await _themeSyncCallback!(_themeMode == ThemeMode.light ? 'light' : 'dark');
    }
  }

  Future<void> applyThemePreference(
    String? preference, {
    bool persist = true,
    bool syncBackend = false,
  }) async {
    if (preference == null || preference.isEmpty) return;
    final normalized = preference.toLowerCase();
    if (normalized == 'light') {
      await setThemeMode(
        ThemeMode.light,
        persist: persist,
        syncBackend: syncBackend,
      );
    } else if (normalized == 'dark') {
      await setThemeMode(
        ThemeMode.dark,
        persist: persist,
        syncBackend: syncBackend,
      );
    }
  }

  Future<void> toggle() async {
    await setThemeMode(
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
