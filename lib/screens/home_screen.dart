import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'landing_screen.dart'; // Added import for LandingScreen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LandingScreen()),
                (Route<dynamic> route) => false,
              ); // Navigate to LandingScreen and clear stack
            },
          ),
        ],
      ),
      body: Center(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Text(
              'Welcome, ${authProvider.userEmail ?? 'User'}!',
              style: const TextStyle(fontSize: 24),
            );
          },
        ),
      ),
    );
  }
}
