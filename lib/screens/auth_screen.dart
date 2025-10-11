// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart'; // Import for AAD OAuth
import 'package:provider/provider.dart'; // Import for AuthProvider
import '../providers/auth_provider.dart'; // Import AuthProvider
import 'dart:convert'; // Import for JSON decoding
import 'manual_login_screen.dart'; // Import ManualLoginScreen
import '../main.dart'; // For MainScreen navigation
import 'onboarding_screen.dart'; // Import OnboardingScreen

class AuthScreen extends StatefulWidget {
  final FlutterAadOauth oauth; // Receive the oauth object
  const AuthScreen({super.key, required this.oauth}); // Update constructor

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  String? _extractEmailFromIdToken(String? idToken) {
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = String.fromCharCodes(base64Url.decode(normalized));
      final Map<String, dynamic> claims =
          jsonDecode(payload) as Map<String, dynamic>;
      final value =
          (claims['preferred_username'] ?? claims['upn'] ?? claims['email'])
              ?.toString();
      return value;
    } catch (_) {
      return null;
    }
  }

  double _discsOpacity = 0.0; // Initial opacity for discs.png

  @override
  void initState() {
    super.initState();
    // Trigger fade-in animation when the screen is initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Set to transparent to show background image
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Khonology Asset
                  Image.asset(
                    'assets/images/khono.png', // Khonology asset
                    height: 100, // Adjust height as needed
                  ),
                  const SizedBox(height: 48), // Adjusted spacing
                  // Removed 'KHONOLOGY' text
                  const SizedBox(height: 32),
                  const Text(
                    'Select Login Preference',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLoginButton(
                    text: 'MICROSOFT LOGIN',
                    color: const Color(0xFFC10D00),
                    onPressed: () async {
                      try {
                        widget.oauth.setContext(context);
                        await widget.oauth.logout();
                        if (!mounted) return;
                        await widget.oauth.login();
                        if (!mounted) return;
                        final idToken = await widget.oauth.getIdToken();
                        final email = _extractEmailFromIdToken(idToken);
                        if (email == null ||
                            !email.toLowerCase().endsWith('@khonology.com')) {
                          await widget.oauth.logout();
                          if (!mounted) return;
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Only khonology.com accounts are allowed',
                              ),
                            ),
                          );
                          return;
                        }
                        if (!mounted) return;
                        await context.read<AuthProvider>().login(
                          email,
                          role: null,
                        ); // Role is not selected on this screen yet
                        if (!mounted) return;
                        // After successful Microsoft login, go directly to MainScreen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(),
                          ),
                          (route) => false,
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Microsoft sign-in failed: $e'),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLoginButton(
                    text: 'MANUAL LOGIN',
                    color: const Color(0xFFC10D00),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ManualLoginScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16), // Added spacing between buttons
                  _buildLoginButton(
                    text: 'ONBOARD WITH US',
                    color: Colors.grey,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              OnboardingScreen(oauth: widget.oauth),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  // Logo Asset
                  AnimatedOpacity(
                    opacity: _discsOpacity,
                    duration: const Duration(milliseconds: 1000),
                    child: Image.asset(
                      'assets/images/discs.png', // Logo asset
                      height: 80, // Adjust height as needed
                    ),
                  ),
                  // Removed 'OGC' text as per instruction
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required String text,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50.0),
      ),
      child: MaterialButton(
        onPressed: onPressed, // Use the passed onPressed callback
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
