import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'screens/entity_management_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/module_access_screen.dart';
import 'screens/module_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/landing_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_alert_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'providers/user_provider.dart';
import 'theme/app_themes.dart';
import 'services/sound_system.dart';
import 'services/version_service.dart';
import 'screens/admin_profile_screen.dart';
import 'screens/staff_profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'widgets/side_menu.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'firebase_options.dart'; // Import generated Firebase options
import 'generated/app_localizations.dart';

// Import for web-specific functionality
import 'e2e_browser_query_stub.dart'
    if (dart.library.html) 'e2e_browser_query_web.dart'
    as e2e_browser_query;
import 'flutter_ready_body_stub.dart'
    if (dart.library.html) 'flutter_ready_body_web.dart'
    as flutter_ready_body;
import 'widgets/flutter_web_readiness.dart';

/// Headless browsers (e.g. Cypress / Electron) sometimes report locales that
/// break [Locale] construction ("Incorrect locale information provided").
Locale _resolveApplicationLocale(
  List<Locale>? locales,
  Iterable<Locale> supported,
) {
  const fallback = Locale('en');
  if (locales == null || locales.isEmpty) {
    return fallback;
  }
  for (final device in locales) {
    final resolved = _trySupportedLocale(device, supported);
    if (resolved != null) {
      return resolved;
    }
  }
  return fallback;
}

Locale? _trySupportedLocale(Locale device, Iterable<Locale> supported) {
  try {
    if (device.languageCode.isEmpty) {
      return null;
    }
    // Dart [Locale] only allows ISO 3166-1 alpha-2 for country (2 letters).
    // Headless Chrome/Electron may report "001", script subtags, etc. — those throw.
    final cc = device.countryCode;
    final country =
        (cc != null && cc.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(cc))
        ? cc
        : null;
    final candidate = Locale(device.languageCode, country);
    for (final s in supported) {
      if (s.languageCode == candidate.languageCode) {
        return candidate;
      }
    }
  } catch (_) {
    /* invalid device locale */
  }
  return null;
}

void main() async {
  // Made main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Initialize Firebase
  debugPrint('Firebase initialized successfully!'); // Debug print
  // So version widget can fetch latest from backend and stop being stuck on build-time version
  VersionService.versionBaseUrl = ApiConfig.baseUrl;

  final prefs = await SharedPreferences.getInstance();
  final storedTheme = prefs.getString(ThemeModeProvider.prefsKey);
  final ThemeMode initialThemeMode = storedTheme == 'light'
      ? ThemeMode.light
      : ThemeMode.dark;

  if (kIsWeb) {
    flutter_ready_body.setFlutterReadyAttribute(false);
  }
  runApp(MyApp(initialThemeMode: initialThemeMode));

  // Mark app as ready after first frame for Cypress E2E testing
  if (kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      flutter_ready_body.setFlutterReadyAttribute(true);
    });
  }
}

/// Web-only: open `/?e2e=auth` to skip the landing screen and start on [AuthScreen]
/// (manual login / onboarding). For automated tests; does not bypass authentication.
bool _e2eStartAtAuthScreen() {
  if (!kIsWeb) return false;
  try {
    if (Uri.base.queryParameters['e2e'] == 'auth') return true;
    return e2e_browser_query.browserUrlHasE2eAuth();
  } catch (_) {
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialThemeMode = ThemeMode.dark});

  final ThemeMode initialThemeMode;

  @override
  Widget build(BuildContext context) {
    return FlutterWebReadiness(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => AdminAlertProvider()),
          ChangeNotifierProxyProvider<AuthProvider, ThemeModeProvider>(
            create: (_) => ThemeModeProvider(initialMode: initialThemeMode),
            update: (_, authProvider, themeProvider) {
              final provider =
                  themeProvider ?? ThemeModeProvider(initialMode: initialThemeMode);
              provider.setThemeSyncCallback(
                authProvider.syncThemePreferenceAndRefreshToken,
              );
              return provider;
            },
          ),
        ],
        child: Consumer<ThemeModeProvider>(
          builder: (context, themeModeProvider, _) {
            return MaterialApp(
              title: 'Khonology',
              theme: AppThemes.light,
              darkTheme: AppThemes.dark,
              themeMode: themeModeProvider.themeMode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              // Web: never trust navigator locale alone (some embedded browsers break Locale()).
              locale: kIsWeb ? const Locale('en') : null,
              localeListResolutionCallback: kIsWeb
                  ? null
                  : _resolveApplicationLocale,
              // Enable accessibility for testing
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                // Enable semantics for accessibility testing
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    accessibleNavigation: true,
                    disableAnimations: true,
                    invertColors: false,
                    highContrast: false,
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(fontFamily: 'Poppins'),
                    child: Semantics(child: child ?? const SizedBox.shrink()),
                  ),
                );
              },
              home: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  // Always use Modules screen (index 3) for authenticated users on login
                  // This ensures both Staff and Admin users land on Modules screen
                  final initialIndex = authProvider.isAuthenticated ? 3 : null;

                  if (authProvider.isAuthenticated) {
                    return MainScreen(
                      role: authProvider.userRole,
                      initialIndex: initialIndex,
                    );
                  }
                  if (_e2eStartAtAuthScreen()) {
                    return const AuthScreen();
                  }
                  return LandingScreen();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String? role; // New: Optional role parameter
  final int? initialIndex; // Optional initial screen index
  /// When true, plays login success sound once after the user has landed (post-frame).
  final bool playLoginSuccessSound;

  const MainScreen({
    super.key,
    this.role,
    this.initialIndex,
    this.playLoginSuccessSound = false,
  }); // Modified constructor

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 3; // Initialize to Modules screen (index 3)
  AdminAlertProvider? _adminAlertProvider;
  Timer? _staffBellShakeTimer;
  late final AnimationController _bellShakeController;
  late final Animation<double> _bellShakeAnimation;

  // Check if current user is Admin
  bool _isAdmin() {
    final authProvider = context.read<AuthProvider>();
    final role = authProvider.userRole?.toLowerCase() ?? '';
    return role == 'admin';
  }

  // Check if screen index is Admin-only
  bool _isAdminOnlyScreen(int index) {
    // Indices 0 (User Management), 1 (Entity Management), and 2 (Module Access) are Admin-only
    return index == 0 || index == 1 || index == 2;
  }

  // Get allowed screen index for Staff users
  int _getAllowedScreenIndex(int requestedIndex) {
    if (!_isAdmin() && _isAdminOnlyScreen(requestedIndex)) {
      // Staff users trying to access Admin screens are redirected to Modules
      return 3;
    }
    return requestedIndex;
  }

  @override
  void initState() {
    super.initState();
    _bellShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bellShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _bellShakeController, curve: Curves.easeInOut),
    );
    _staffBellShakeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final role = (context.read<AuthProvider>().userRole ?? '').toLowerCase();
      final unread = context.read<AdminAlertProvider>().unreadCount;
      if (role == 'staff' && unread > 0 && !_bellShakeController.isAnimating) {
        _bellShakeController.forward(from: 0);
      }
    });
    // Both Staff and Admin users should ALWAYS land on Modules screen (index 3) on login
    // Ignore widget.initialIndex and always use Modules screen (index 3) to prevent
    // old stored screen indices from interfering with login redirects
    final finalIndex = 3; // Always Modules screen on login

    _selectedIndex = finalIndex;

    // Save the initial index as current screen index for refresh persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.playLoginSuccessSound) {
        SoundSystem.playLoginSuccess();
      }
      final authProvider = context.read<AuthProvider>();
      authProvider.saveCurrentScreenIndex(finalIndex);
      authProvider.clearInitialScreenIndex();
      if ((authProvider.userRole ?? '').toLowerCase() == 'admin') {
        final userProvider = context.read<UserProvider>();
        userProvider.fetchUsers(forceRefresh: true);
        if (userProvider.hasCachedData) {
          userProvider.refreshUsersInBackground();
        }
      }

      final alertsProvider = context.read<AdminAlertProvider>();
      _adminAlertProvider = alertsProvider;
      alertsProvider.addListener(_onAdminAlertUpdate);
      alertsProvider.start(
        authProvider.userRole ?? '',
        userEmail: authProvider.userEmail ?? '',
      );
    });
  }

  @override
  void dispose() {
    _staffBellShakeTimer?.cancel();
    _bellShakeController.dispose();
    _adminAlertProvider?.removeListener(_onAdminAlertUpdate);
    _adminAlertProvider?.stop();
    super.dispose();
  }

  void _onAdminAlertUpdate() {
    if (!mounted || _adminAlertProvider == null) {
      return;
    }
    // Do not show bottom toasts; notifications are viewed in Notifications screen.
    _adminAlertProvider!.takeNewAlerts();
  }

  Future<void> _openNotificationsScreen() async {
    SoundSystem.playButtonClick();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  // Remove the getter since we now have persistent screens

  void _onItemTapped(int index) {
    // Check if Staff user is trying to access Admin-only screen
    final allowedIndex = _getAllowedScreenIndex(index);

    if (!_isAdmin() && _isAdminOnlyScreen(index)) {
      // Redirect Staff users to Modules screen if they try to access Admin screens
      setState(() {
        _selectedIndex = 3;
      });
      context.read<AuthProvider>().saveCurrentScreenIndex(3);

      // Show message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access denied. Admin privileges required.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Color(0xFFC10D00),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = allowedIndex;
    });
    // Save current screen index for refresh persistence
    context.read<AuthProvider>().saveCurrentScreenIndex(allowedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final adminAlertProvider = context.watch<AdminAlertProvider>();
    final unreadAlerts = adminAlertProvider.unreadCount;
    final role = (context.watch<AuthProvider>().userRole ?? '').toLowerCase();
    final isStaff = role == 'staff';
    final users = userProvider.users;

    final pendingUsers = users
        .where((u) => u.status.toLowerCase() == 'pending')
        .toList();

    final activeUsersWithoutAssignments = users
        .where(
          (u) =>
              u.status.toLowerCase() == 'active' &&
              ((u.entity == null || u.entity!.isEmpty) ||
                  (u.moduleAccess == null || u.moduleAccess!.isEmpty)),
        )
        .toList();

    final onboardingAlertCount = _isAdmin()
        ? pendingUsers.length + activeUsersWithoutAssignments.length
        : 0;
    final totalAlertCount = unreadAlerts + onboardingAlertCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          // The leading IconButton to open the drawer will be removed later.
        ),
      ),
      body: Stack(
        children: [
          Row(
            children: [
              SideMenu(
                selectedIndex: _selectedIndex <= 4 ? _selectedIndex : 0,
                onItemSelected: _onItemTapped,
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: const [
                          UserManagementScreen(),
                          EntityManagementScreen(),
                          ModuleAccessScreen(),
                          ModuleScreen(),
                          _ProfileScreenPlaceholder(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openNotificationsScreen,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: AnimatedBuilder(
                            animation: _bellShakeAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: isStaff ? _bellShakeAnimation.value : 0.0,
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/images/siderbar/7.png',
                              width: 70,
                              height: 70,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        if (totalAlertCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFC10D00)),
                              ),
                              child: Text(
                                totalAlertCount > 99
                                    ? '99+'
                                    : '$totalAlertCount',
                                style: const TextStyle(
                                  color: Color(0xFFC10D00),
                                  fontSize: 10,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows Admin or Staff profile screen based on current user role.
class _ProfileScreenPlaceholder extends StatelessWidget {
  const _ProfileScreenPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final role = authProvider.userRole?.toLowerCase() ?? '';
        if (role == 'admin') {
          return const AdminProfileScreen();
        }
        return const StaffProfileScreen();
      },
    );
  }
}
