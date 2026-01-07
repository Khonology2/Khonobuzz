import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/user_provider.dart';
import '../widgets/version_control.dart';
import 'auth_screen.dart';
import '../widgets/floating_circles_particle_animation.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  double _logoOpacity = 0.0;
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
  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey =
      GlobalKey();
  VoidCallback? _pendingNavigation;
  bool _isAnimatingNavigation = false;

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

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _logoOpacity = 1.0;
      });
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _btnController.forward();
    });
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
                  nav();
                }
              },
            ),
            const VersionControlOverlay(),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedOpacity(
                    opacity: _logoOpacity,
                    duration: const Duration(milliseconds: 1000),
                    child: Image.asset('assets/images/khono.png', height: 150),
                  ),
                  const SizedBox(height: 50),
                  const Text(
                    'Welcome to KhonoBuzz',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontFamily: 'Poppins',
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
                          _pingBackend();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AuthScreen(),
                            ),
                          );
                        },
                        animationKey: _animationKey,
                      ),
                    ),
                  ),
                ],
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
    GlobalKey<FloatingCirclesParticleAnimationState>? animationKey,
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
          if (_isAnimatingNavigation) {
            return;
          }
          _clickController.forward(from: 0);
          if (animationKey?.currentState != null) {
            animationKey!.currentState!.triggerParticleExplosion();
          }
          if (onPressed != null) {
            _pendingNavigation = onPressed;
            _isAnimatingNavigation = true;
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

  Future<void> _pingBackend() async {
    try {
      debugPrint(
        '[LandingScreen] Starting backend warm-up and user prefetch',
      );
      final userProvider = context.read<UserProvider>();
      debugPrint(
        '[LandingScreen] Obtained UserProvider instance for prefetch',
      );
      final uri = Uri.parse(ApiConfig.baseUrl);
      debugPrint('[LandingScreen] Pinging backend at: ${uri.toString()}');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      debugPrint(
        '[LandingScreen] Backend ping completed with status: ${response.statusCode}',
      );
      debugPrint(
        '[LandingScreen] Triggering initial user fetch from backend (forceRefresh=true)',
      );
      userProvider.fetchUsers(forceRefresh: true);
    } catch (e) {
      debugPrint(
        '[LandingScreen] Backend warm-up or user prefetch failed: $e',
      );
    }
  }
}

class _BubblesPainter extends CustomPainter {
  final double progress;
  final Color color;
  _BubblesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final topXs = [0.05, 0.15, 0.3, 0.5, 0.7, 0.85, 0.95];
    final bottomXs = [0.1, 0.25, 0.45, 0.6, 0.75, 0.9];
    for (final x in topXs) {
      final p = progress;
      final y = (0.0 - size.height * (0.8 * p));
      final baseRadius = (size.height * 0.12) * (1.0 - p);
      if (baseRadius <= 0) continue;
      final strokeWidth = baseRadius * 0.6;
      final radius = baseRadius - strokeWidth / 2;
      paint
        ..color = color.withValues(alpha: 0.5 * (1.0 - p))
        ..strokeWidth = strokeWidth;
      final center = Offset(x * size.width, y + size.height * 0.1);
      final rect = Rect.fromCircle(center: center, radius: radius);
      const startAngle = -math.pi * 0.75;
      const sweepAngle = math.pi * 1.42;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
    for (final x in bottomXs) {
      final p = progress;
      final y = size.height + size.height * (0.8 * p);
      final baseRadius = (size.height * 0.12) * (1.0 - p);
      if (baseRadius <= 0) continue;
      final strokeWidth = baseRadius * 0.6;
      final radius = baseRadius - strokeWidth / 2;
      paint
        ..color = color.withValues(alpha: 0.5 * (1.0 - p))
        ..strokeWidth = strokeWidth;
      final center = Offset(x * size.width, y - size.height * 0.1);
      final rect = Rect.fromCircle(center: center, radius: radius);
      const startAngle = -math.pi * 0.75;
      const sweepAngle = math.pi * 1.42;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
