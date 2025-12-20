import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'manual_login_screen.dart';
import '../main.dart';
import 'onboarding_screen.dart';
import '../widgets/floating_circles_particle_animation.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  double _discsOpacity = 0.0;
  bool _isCheckingRedirect = false;
  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey =
      GlobalKey();
  VoidCallback? _pendingNavigation;
  bool _isAnimatingNavigation = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });

    if (kIsWeb) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _handleRedirectResult();
      });
    }
  }

  Future<void> _handleRedirectResult() async {
    if (_isCheckingRedirect) return;
    _isCheckingRedirect = true;

    try {
      debugPrint('Checking for redirect result...');
      final credential = await fb_auth.FirebaseAuth.instance
          .getRedirectResult();

      if (credential.user != null) {
        debugPrint('Redirect result found, user: ${credential.user?.email}');
        final email = credential.user?.email;
        if (email != null && email.toLowerCase().endsWith('@khonology.com')) {
          if (!mounted) {
            _isCheckingRedirect = false;
            return;
          }
          final authProvider = context.read<AuthProvider>();
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          final success = await authProvider.login(email, role: null);
          if (!mounted) {
            _isCheckingRedirect = false;
            return;
          }

          if (success) {
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainScreen(initialIndex: 8),
              ),
              (route) => false,
            );
          } else {
            await fb_auth.FirebaseAuth.instance.signOut();
            if (!mounted) {
              _isCheckingRedirect = false;
              return;
            }
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
        debugPrint('No redirect result found');
      }
    } catch (e, stackTrace) {
      debugPrint('Redirect result error: $e');
      debugPrint('Stack trace: $stackTrace');
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            FloatingCirclesParticleAnimation(
              key: _animationKey,
              onAnimationComplete: () {
                if (_pendingNavigation != null) {
                  final nav = _pendingNavigation!;
                  _pendingNavigation = null;
                  _isAnimatingNavigation = false;
                  if (mounted) {
                    nav();
                  }
                }
              },
            ),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/khono.png', height: 100),
                      const SizedBox(height: 48),

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
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          final authProvider = context.read<AuthProvider>();
                          try {
                            final provider = fb_auth.OAuthProvider(
                              'microsoft.com',
                            );

                            fb_auth.UserCredential credential;
                            if (kIsWeb) {
                              debugPrint(
                                'Initiating Microsoft sign-in redirect...',
                              );
                              await fb_auth.FirebaseAuth.instance
                                  .signInWithRedirect(provider);

                              return;
                            } else {
                              credential = await fb_auth.FirebaseAuth.instance
                                  .signInWithProvider(provider);
                            }

                            final email = credential.user?.email;
                            if (email == null ||
                                !email.toLowerCase().endsWith(
                                  '@khonology.com',
                                )) {
                              await fb_auth.FirebaseAuth.instance.signOut();
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Only khonology.com accounts are allowed',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (!mounted) return;
                            final success = await authProvider.login(
                              email,
                              role: null,
                            );
                            if (!mounted) return;

                            if (!success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Login failed. Please try again later.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (!mounted) return;
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MainScreen(initialIndex: 8),
                              ),
                              (route) => false,
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
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
                          if (_isAnimatingNavigation) {
                            return;
                          }
                          _isAnimatingNavigation = true;
                          final navigator = Navigator.of(context);
                          _pendingNavigation = () {
                            navigator.push(
                              MaterialPageRoute(
                                builder: (context) => const ManualLoginScreen(),
                              ),
                            );
                          };
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildLoginButton(
                        text: 'ONBOARD WITH US',
                        color: Colors.grey,
                        onPressed: () {
                          if (_isAnimatingNavigation) {
                            return;
                          }
                          _isAnimatingNavigation = true;
                          final navigator = Navigator.of(context);
                          _pendingNavigation = () {
                            navigator.push(
                              MaterialPageRoute(
                                builder: (context) => const OnboardingScreen(),
                              ),
                            );
                          };
                        },
                      ),
                      const SizedBox(height: 48),

                      AnimatedOpacity(
                        opacity: _discsOpacity,
                        duration: const Duration(milliseconds: 1000),
                        child: Image.asset(
                          'assets/images/discs.png',
                          height: 80,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton({
    required String text,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return _ClickBubblyButton(
      text: text,
      color: color,
      onPressed: () {
        if (onPressed == null) {
          return;
        }
        if (_animationKey.currentState != null) {
          _animationKey.currentState!.triggerParticleExplosion();
        }
        onPressed();
      },
      animationKey: null,
    );
  }
}

class _AnimatedBubblyButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback? onPressed;
  final int bounceDelayMs;
  const _AnimatedBubblyButton({
    required this.text,
    required this.color,
    required this.onPressed,
    required this.bounceDelayMs,
  });

  @override
  State<_AnimatedBubblyButton> createState() => _AnimatedBubblyButtonState();
}

class _AnimatedBubblyButtonState extends State<_AnimatedBubblyButton>
    with TickerProviderStateMixin {
  late AnimationController _btnController;
  Animation<Offset> _btnOffset = const AlwaysStoppedAnimation<Offset>(
    Offset.zero,
  );
  late AnimationController _pulseController;
  Animation<double> _pulseScale = const AlwaysStoppedAnimation<double>(1.0);
  Animation<double> _ringRadius = const AlwaysStoppedAnimation<double>(0.0);
  Animation<double> _ringOpacity = const AlwaysStoppedAnimation<double>(0.0);
  late AnimationController _clickController;
  Animation<double> _clickProgress = const AlwaysStoppedAnimation<double>(0.0);

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
    ).animate(CurvedAnimation(parent: _btnController, curve: Curves.bounceOut));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_pulseController);
    _ringRadius = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 50.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 50.0, end: 0.0),
        weight: 30,
      ),
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

    Future.delayed(Duration(milliseconds: widget.bounceDelayMs), () {
      if (mounted) _btnController.forward();
    });
  }

  @override
  void dispose() {
    _clickController.dispose();
    _pulseController.dispose();
    _btnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _btnOffset,
      child: ScaleTransition(
        scale: _pulseScale,
        child: AnimatedBuilder(
          animation: _pulseScale,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(50.0),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(
                          alpha: _ringOpacity.value,
                        ),
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
                            color: widget.color,
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
              if (widget.onPressed != null) {
                Future.delayed(
                  const Duration(milliseconds: 250),
                  widget.onPressed!,
                );
              }
            },
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              widget.text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
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
      canvas.drawCircle(
        Offset(x * size.width, y + size.height * 0.1),
        r,
        paint,
      );
    }
    for (final x in bottomXs) {
      final p = progress;
      final y = size.height + size.height * (0.8 * p);
      final r = (size.height * 0.12) * (1.0 - p);
      paint.color = color.withValues(alpha: 0.5 * (1.0 - p));
      canvas.drawCircle(
        Offset(x * size.width, y - size.height * 0.1),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _ClickBubblyButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback? onPressed;
  final GlobalKey<FloatingCirclesParticleAnimationState>? animationKey;
  const _ClickBubblyButton({
    required this.text,
    required this.color,
    required this.onPressed,
    this.animationKey,
  });

  @override
  State<_ClickBubblyButton> createState() => _ClickBubblyButtonState();
}

class _ClickBubblyButtonState extends State<_ClickBubblyButton>
    with TickerProviderStateMixin {
  late AnimationController _clickController;
  Animation<double> _clickProgress = const AlwaysStoppedAnimation<double>(0.0);

  @override
  void initState() {
    super.initState();
    _clickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _clickProgress = CurvedAnimation(
      parent: _clickController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _clickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC10D00);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 250,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(50.0),
          ),
          child: MaterialButton(
            onPressed: () {
              _clickController.forward(from: 0);
              if (widget.onPressed != null) {
                widget.onPressed!();
              }
            },
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              widget.text,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _clickController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BubblesPainter(
                    progress: _clickProgress.value,
                    color: red,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
