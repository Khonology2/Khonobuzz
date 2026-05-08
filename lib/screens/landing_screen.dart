import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_mode_provider.dart';
import '../services/sound_system.dart';
import 'auth_screen.dart';
import 'learn_more_screen.dart';
import '../theme/app_backgrounds.dart';
import '../theme/app_themes.dart';
import '../widgets/version_control_widget.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isCheckingRedirect = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _handleRedirectResult();
      });
    }
  }

  Future<void> _handleRedirectResult() async {
    if (!kIsWeb) return;
    if (_isCheckingRedirect) return;
    _isCheckingRedirect = true;

    try {
      debugPrint('LandingScreen: Checking for Microsoft redirect result...');
      final credential = await fb_auth.FirebaseAuth.instance
          .getRedirectResult();

      if (credential.user != null) {
        debugPrint(
          'LandingScreen: Redirect result user: ${credential.user?.email}',
        );
        final email = credential.user?.email;
        if (email != null && email.toLowerCase().endsWith('@khonology.com')) {
          if (!mounted) {
            _isCheckingRedirect = false;
            return;
          }
          final authProvider = context.read<AuthProvider>();
          final messenger = ScaffoldMessenger.of(context);
          final success = await authProvider.login(email, role: null);
          if (!mounted) {
            _isCheckingRedirect = false;
            return;
          }

          if (success) {
            await context.read<ThemeModeProvider>().applyThemePreference(
              authProvider.userThemePreference,
            );
          }

          if (!success) {
            await fb_auth.FirebaseAuth.instance.signOut();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Login failed. Please try again later.'),
              ),
            );
          }
        } else {
          await fb_auth.FirebaseAuth.instance.signOut();
          if (!mounted) {
            _isCheckingRedirect = false;
            return;
          }
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Only khonology.com accounts are allowed'),
            ),
          );
        }
      } else {
        debugPrint('LandingScreen: No redirect result found');
      }
    } catch (e, stackTrace) {
      debugPrint('LandingScreen redirect result error: $e');
      debugPrint('LandingScreen stack trace: $stackTrace');
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _isCheckingRedirect = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final welcomeColor = isLight ? Colors.black : Colors.white;
    final subtitleColor = isLight ? Colors.black54 : Colors.white70;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(appBackgroundAsset(context)),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/khono.png', height: 150),
                  const SizedBox(height: 50),
                  Text(
                    'Welcome to KhonoBuzz',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: welcomeColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: subtitleColor,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 50),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'GET STARTED',
                          button: true,
                          child: _buildLandingActionButton(
                            text: 'GET STARTED',
                            isPrimary: true,
                            onPressed: () {
                              AuthProvider.warmUpBackendForLogin();
                              _pingBackend();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AuthScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 22),
                        Semantics(
                          label: 'LEARN MORE',
                          button: true,
                          child: _buildLandingActionButton(
                            text: 'LEARN MORE',
                            isPrimary: false,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LearnMoreScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Image.asset(
                    isLight
                        ? 'assets/images/red_disc.png'
                        : 'assets/images/discs.png',
                    height: isLight ? 110 : 72,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: SafeArea(
                child: VersionControlWidget(
                  textColor: isLight ? Colors.black54 : Colors.white70,
                  hoverColor: isLight ? Colors.black : Colors.white,
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Consumer<ThemeModeProvider>(
                  builder: (context, themeMode, _) {
                    return FloatingActionButton(
                      mini: true,
                      shape: const CircleBorder(),
                      heroTag: 'landing_theme_toggle_fab',
                      onPressed: () {
                        SoundSystem.playButtonClick();
                        themeMode.toggle();
                      },
                      backgroundColor: AppThemes.light.primaryColor,
                      child: Icon(
                        themeMode.isLight
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandingActionButton({
    required String text,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isPrimary
        ? const Color(0xFFC10D00)
        : Colors.transparent;
    final fg = isPrimary
        ? Colors.white
        : (isLight ? Colors.black : Colors.white);
    final borderColor = isPrimary
        ? Colors.transparent
        : (isLight ? Colors.black : Colors.white);

    return Container(
      width: 168,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            SoundSystem.playButtonClick();
            onPressed();
          },
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pingBackend() async {
    try {
      debugPrint('[LandingScreen] Starting backend warm-up and user prefetch');
      final userProvider = context.read<UserProvider>();
      await userProvider.prefetchUsersForLogin(forceRefresh: true);
    } catch (e) {
      debugPrint('[LandingScreen] Backend warm-up or user prefetch failed: $e');
    }
  }
}
