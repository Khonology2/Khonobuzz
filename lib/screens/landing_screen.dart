// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_aad_oauth/model/config.dart'; // Import for AAD OAuth config
import 'auth_screen.dart'; // Import AuthScreen
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart'; // Import FlutterAadOauth

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  double _logoOpacity = 0.0; // Initial opacity for khono.png

  @override
  void initState() {
    super.initState();
    // Trigger fade-in animation when the screen is initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _logoOpacity = 1.0;
      });
    });
  }

  // Azure AD configuration
  static const String _tenantId =
      'aacabed7-5b1f-403b-81ec-c4fbec6948d2'; // Replace with your Tenant ID
  static const String _clientId =
      '3592de85-8d67-43ee-a2c6-66e3f92d8e3e'; // Replace with your Client ID
  static const String _redirectPath = '/auth.html'; // Web redirect page
  // Mobile redirect URIs must be registered in Azure AD and match app config
  // Replace the placeholders below once you generate the Android signature hash
  // and set the iOS URL scheme.
  static const String _androidRedirectUri =
      'msauth://com.example.khonology_app/REPLACE_WITH_SIGNATURE_HASH';
  static const String _iosRedirectUri =
      'msauth.com.example.khonology-app://auth';

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
            ), // Use the new background image
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Your Logo
              // Image.asset(
              //   'assets/images/logo.png',
              //   height: 150,
              // ),
              AnimatedOpacity(
                opacity: _logoOpacity,
                duration: const Duration(milliseconds: 1000),
                child: Image.asset(
                  'assets/images/khono.png',
                  height: 150, // Adjust height as needed
                ),
              ),
              const SizedBox(height: 50),
              const Text(
                'Welcome to Khonobuzz',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Poppins', // Apply Poppins font
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  fontFamily: 'Poppins', // Apply Poppins font
                ),
              ),
              const SizedBox(height: 50),
              _buildLoginButton(
                text: 'GET STARTED',
                color: const Color(0xFFC10D00),
                onPressed: () {
                  String redirectUri;
                  // Select redirect URI per-platform
                  if (kIsWeb) {
                    final current = Uri.base;
                    redirectUri = Uri(
                      host: current.host,
                      scheme: current.scheme,
                      port: current.port,
                      path: _redirectPath,
                    ).toString();
                  } else if (Platform.isAndroid) {
                    if (_androidRedirectUri.contains(
                      'REPLACE_WITH_SIGNATURE_HASH',
                    )) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Android redirect URI not configured. Please set signature hash.',
                          ),
                        ),
                      );
                      return;
                    }
                    redirectUri = _androidRedirectUri;
                  } else if (Platform.isIOS) {
                    redirectUri = _iosRedirectUri;
                  } else {
                    // Fallback to web-style in unsupported platforms (desktop)
                    final current = Uri.base;
                    redirectUri = Uri(
                      host: current.host,
                      scheme: current.scheme,
                      port: current.port,
                      path: _redirectPath,
                    ).toString();
                  }

                  // Include email scope to ensure id_token contains email/claims
                  final scope = 'openid profile email offline_access';
                  final responseType = 'code';

                  final Config aadConfig = Config(
                    azureTenantId: _tenantId,
                    clientId: _clientId,
                    scope: scope,
                    redirectUri: redirectUri,
                    responseType: responseType,
                  );
                  FlutterAadOauth oauth = FlutterAadOauth(aadConfig);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AuthScreen(oauth: oauth),
                    ),
                  );
                },
              ),
            ],
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
        onPressed: onPressed,
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
