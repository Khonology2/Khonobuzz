import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/resource_allocation_screen.dart';
import 'screens/time_keeping_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/project_data_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/module_screen.dart'; // Import ModuleScreen
import 'screens/entity_management_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/module_access_screen.dart';
import 'screens/landing_screen.dart'; // Import LandingScreen
import 'providers/auth_provider.dart';
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
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
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
            // Always use Modules screen (index 9) for authenticated users on login
            // This ensures both Staff and Admin users land on Modules screen
            final initialIndex = authProvider.isAuthenticated ? 9 : null;

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

  const MainScreen({
    super.key,
    this.role,
    this.initialIndex,
  }); // Modified constructor

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 9; // Initialize to Modules screen (index 9)

  // Check if current user is Admin
  bool _isAdmin() {
    final authProvider = context.read<AuthProvider>();
    final role = authProvider.userRole?.toLowerCase() ?? '';
    return role == 'admin';
  }

  // Check if screen index is Admin-only
  bool _isAdminOnlyScreen(int index) {
    // Indices 6 (User Management), 7 (Entity Management), and 8 (Module Access) are Admin-only
    return index == 6 || index == 7 || index == 8;
  }

  // Get allowed screen index for Staff users
  int _getAllowedScreenIndex(int requestedIndex) {
    if (!_isAdmin() && _isAdminOnlyScreen(requestedIndex)) {
      // Staff users trying to access Admin screens are redirected to Modules
      return 9;
    }
    return requestedIndex;
  }

  @override
  void initState() {
    super.initState();
    // Both Staff and Admin users should ALWAYS land on Modules screen (index 9) on login
    // Ignore widget.initialIndex and always use Modules screen (index 9) to prevent
    // old stored screen indices from interfering with login redirects
    final finalIndex = 9; // Always Modules screen on login

    _selectedIndex = finalIndex;

    // Save the initial index as current screen index for refresh persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        authProvider.saveCurrentScreenIndex(finalIndex);
        // Clear the initial screen index after using it
        authProvider.clearInitialScreenIndex();
      }
    });
  }

  List<Widget> get _screens => [
    const DashboardScreen(),
    const ResourceAllocationScreen(),
    const TimeKeepingScreen(),
    const ProjectDataScreen(),
    const AnalyticsScreen(),
    const ProfileScreen(),
    const UserManagementScreen(),
    const EntityManagementScreen(),
    const ModuleAccessScreen(),
    const ModuleScreen(), // Modules screen at index 9
    const ProjectsScreen(), // Projects screen at index 10
  ];

  void _onItemTapped(int index) {
    // Check if Staff user is trying to access Admin-only screen
    final allowedIndex = _getAllowedScreenIndex(index);

    if (!_isAdmin() && _isAdminOnlyScreen(index)) {
      // Redirect Staff users to Modules screen if they try to access Admin screens
      setState(() {
        _selectedIndex = 9;
      });
      context.read<AuthProvider>().saveCurrentScreenIndex(9);

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
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          // The leading IconButton to open the drawer will be removed later.
        ),
      ),
      body: Row(
        children: [
          SideMenu(
            selectedIndex: (_selectedIndex < _screens.length)
                ? _selectedIndex
                : 0,
            onItemSelected: _onItemTapped,
          ),
          Expanded(
            child:
                _screens[(_selectedIndex < _screens.length)
                    ? _selectedIndex
                    : 0],
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () {
          // Chatbot navigation disabled for now
        },
        child: Image.asset(
          'assets/images/Chatbot_Red.png',
          width: 60, // Adjust width as needed
          height: 60, // Adjust height as needed
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
