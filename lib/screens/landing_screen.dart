// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_aad_oauth/model/config.dart'; // Import for AAD OAuth config (still used for aadConfig)
import 'auth_screen.dart'; // Import AuthScreen

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  double _logoOpacity = 0.0; // Initial opacity for khono.png
  late AnimationController _btnController;
  Animation<Offset> _btnOffset =
      const AlwaysStoppedAnimation<Offset>(Offset.zero);
  late AnimationController _pulseController;
  Animation<double> _pulseScale =
      const AlwaysStoppedAnimation<double>(1.0);
  Animation<double> _ringRadius =
      const AlwaysStoppedAnimation<double>(0.0);
  Animation<double> _ringOpacity =
      const AlwaysStoppedAnimation<double>(0.0);
  late AnimationController _clickController;
  Animation<double> _clickProgress =
      const AlwaysStoppedAnimation<double>(0.0);

  @override
  void initState() {
    super.initState();
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _btnOffset = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _btnController,
        curve: Curves.bounceOut,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_pulseController);
    _ringRadius = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 50.0), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 50.0, end: 0.0), weight: 30),
    ]).animate(_pulseController);
    _ringOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 0.0), weight: 70),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 30),
    ]).animate(_pulseController);
    _clickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _clickProgress = CurvedAnimation(
      parent: _clickController,
      curve: Curves.easeInOut,
    );
    _btnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.repeat(reverse: true);
      }
    });

    // Trigger fade-in animation when the screen is initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _logoOpacity = 1.0;
      });
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _btnController.forward();
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
                'Welcome to KhonoBuzz',
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
              SlideTransition(
                position: _btnOffset,
                child: ScaleTransition(
                  scale: _pulseScale,
                  child: _buildLoginButton(
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
                    // Note: AuthScreen now uses Firebase Auth, oauth parameter no longer needed
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AuthScreen(),
                      ),
                    );
                  },
                  ),
                ),
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
    return AnimatedBuilder(
      animation: _pulseScale,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(50.0),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: _ringOpacity.value),
                    offset: const Offset(0, 0),
                    blurRadius: 0,
                    spreadRadius: _ringRadius.value,
                  ),
                ],
              ),
              child: child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _clickController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _BubblesPainter(
                        progress: _clickProgress.value,
                        color: color,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      child: MaterialButton(
        onPressed: () {
          _clickController.forward(from: 0);
          if (onPressed != null) {
            Future.delayed(const Duration(milliseconds: 250), onPressed);
          }
        },
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
  
  @override
  void dispose() {
    _pulseController.dispose();
    _btnController.dispose();
    _clickController.dispose();
    super.dispose();
  }
}

class _BubblesPainter extends CustomPainter {
  final double progress;
  final Color color;
  _BubblesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final topXs = [0.05, 0.15, 0.3, 0.5, 0.7, 0.85, 0.95];
    final bottomXs = [0.1, 0.25, 0.45, 0.6, 0.75, 0.9];
    for (final x in topXs) {
      final p = progress;
      final y = (0.0 - size.height * (0.8 * p));
      final r = (size.height * 0.12) * (1.0 - p);
      paint.color = color.withValues(alpha: 0.5 * (1.0 - p));
      canvas.drawCircle(Offset(x * size.width, y + size.height * 0.1), r, paint);
    }
    for (final x in bottomXs) {
      final p = progress;
      final y = size.height + size.height * (0.8 * p);
      final r = (size.height * 0.12) * (1.0 - p);
      paint.color = color.withValues(alpha: 0.5 * (1.0 - p));
      canvas.drawCircle(Offset(x * size.width, y - size.height * 0.1), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
