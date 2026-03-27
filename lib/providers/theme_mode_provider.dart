import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user choice of light vs dark theme.
/// Callers should pass [initialMode] from prefs (e.g. in [main]) so startup
/// does not race with async SharedPreferences and overwrite a user toggle.
class ThemeModeProvider extends ChangeNotifier {
  static const prefsKey = 'app_theme_mode';

  ThemeMode _themeMode;

  ThemeModeProvider({ThemeMode initialMode = ThemeMode.dark})
      : _themeMode = initialMode;

  ThemeMode get themeMode => _themeMode;

  bool get isLight => _themeMode == ThemeMode.light;

  Future<void> setThemeMode(ThemeMode mode, {bool persist = true}) async {
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
  }

  Future<void> applyThemePreference(
    String? preference, {
    bool persist = true,
  }) async {
    if (preference == null || preference.isEmpty) return;
    final normalized = preference.toLowerCase();
    if (normalized == 'light') {
      await setThemeMode(ThemeMode.light, persist: persist);
    } else if (normalized == 'dark') {
      await setThemeMode(ThemeMode.dark, persist: persist);
    }
  }

  Future<void> toggle() async {
    await setThemeMode(
      _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
