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
import 'screens/user_management_screen.dart';
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
            return authProvider.isAuthenticated
                ? MainScreen(
                    role: authProvider.userRole,
                    initialIndex: authProvider.initialScreenIndex ?? 0,
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

  const MainScreen({super.key, this.role, this.initialIndex}); // Modified constructor

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Set initial index if provided
    if (widget.initialIndex != null) {
      _selectedIndex = widget.initialIndex!;
      // Clear the initial screen index after using it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AuthProvider>().clearInitialScreenIndex();
        }
      });
    }
    // Removed: Display SnackBar with role if available
    // if (widget.role != null) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (mounted) {
    //       ScaffoldMessenger.of(context).showSnackBar(
    //         SnackBar(
    //           content: Text('You have logged in as ${widget.role}'),
    //           duration: const Duration(seconds: 2),
    //         ),
    //       );
    //     }
    //   });
    // }
  }

  List<Widget> get _screens => [
    const DashboardScreen(),
    const ResourceAllocationScreen(),
    const TimeKeepingScreen(),
    const ProjectDataScreen(),
    const AnalyticsScreen(),
    const ProfileScreen(),
    const UserManagementScreen(),
    const ProjectsScreen(), // Added for Assets
    const ModuleScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
            selectedIndex: (_selectedIndex < _screens.length) ? _selectedIndex : 0,
            onItemSelected: _onItemTapped,
          ),
          Expanded(child: _screens[(_selectedIndex < _screens.length) ? _selectedIndex : 0]),
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
