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

  Future<void> toggle() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      _themeMode == ThemeMode.light ? 'light' : 'dark',
    );
  }
}
