import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/entity_management_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/module_access_screen.dart';
import 'screens/module_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/onboarding_alert_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'services/sound_system.dart';
import 'screens/admin_profile_screen.dart';
import 'screens/staff_profile_screen.dart';
import 'widgets/side_menu.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'firebase_options.dart'; // Import generated Firebase options

void main() async {
  // Made main async
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Initialize Firebase
  debugPrint('Firebase initialized successfully!'); // Debug print
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'Khonology',
        theme: ThemeData(
          fontFamily: 'Poppins', // Set Poppins as the default font
          primaryColor: const Color(0xFFC10D00), // Use the specified red color
          colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: const Color(0xFFC10D00),
          ), // Use the specified red color for accent
          scaffoldBackgroundColor: const Color(0xFF1A1A1A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A1A1A),
            foregroundColor: Colors.white,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            bodyMedium: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            titleLarge: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // Always use Modules screen (index 3) for authenticated users on login
            // This ensures both Staff and Admin users land on Modules screen
            final initialIndex = authProvider.isAuthenticated ? 3 : null;

            return authProvider.isAuthenticated
                ? MainScreen(
                    role: authProvider.userRole,
                    initialIndex: initialIndex,
                  ) // Pass role and initialIndex to MainScreen
                : LandingScreen(); // Start with LandingScreen
          },
        ),
        debugShowCheckedModeBanner: false,
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 3; // Initialize to Modules screen (index 3)
  bool _isAlertPanelOpen = false;

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
        userProvider.fetchUsers();
        if (userProvider.hasCachedData) {
          userProvider.refreshUsersInBackground();
        }
      }
    });
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

    final hasOnboardingAlerts =
        _isAdmin() &&
        (pendingUsers.isNotEmpty || activeUsersWithoutAssignments.isNotEmpty);

    return Scaffold(
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
          if (hasOnboardingAlerts)
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isAlertPanelOpen = !_isAlertPanelOpen;
                        });
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC10D00),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pendingUsers.isNotEmpty
                                  ? 'New user onboarded'
                                  : 'Assign access and entity',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isAlertPanelOpen) ...[
                    const SizedBox(height: 8),
                    OnboardingAlertPanel(
                      pendingUsers: pendingUsers,
                      activeUsersWithoutAssignments:
                          activeUsersWithoutAssignments,
                      onClose: () {
                        setState(() {
                          _isAlertPanelOpen = false;
                        });
                      },
                    ),
                  ],
                ],
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
