import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/floating_circles_particle_animation.dart';

class AdminProfileScreen extends StatefulWidget {
  final FlutterAadOauth? oauth;
  const AdminProfileScreen({super.key, this.oauth});

  @override
  AdminProfileScreenState createState() => AdminProfileScreenState();
}

class AdminProfileScreenState extends State<AdminProfileScreen>
    with TickerProviderStateMixin {
  double _discsOpacity = 0.0;
  final bool _isLoading = false;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey =
      GlobalKey();

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/nathi_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            FloatingCirclesParticleAnimation(key: _animationKey),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/khono.png', height: 100),
                      const SizedBox(height: 48),

                      // Admin Profile Header
                      Container(
                        width: 590,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(
                              0xFFC10D00,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: const Color(0xFFC10D00),
                                  child: Text(
                                    authProvider.userEmail
                                            ?.substring(0, 2)
                                            .toUpperCase() ??
                                        'AD',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Administrator',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      Text(
                                        authProvider.userEmail ??
                                            'admin@example.com',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions
                      SizedBox(
                        width: 590,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildButton(
                                text: 'MANAGE USERS',
                                color: const Color(0xFFC10D00),
                                onPressed: () {
                                  // Navigate to user management
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildButton(
                                text: 'MODULE ACCESS',
                                color: Colors.grey[700]!,
                                onPressed: () {
                                  // Navigate to module access
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Refresh Button
                      _buildButton(
                        text: 'REFRESH DATA',
                        color: Colors.blue[700]!,
                        onPressed: () {
                          // Refresh functionality can be added here
                        },
                      ),
                      const SizedBox(height: 48),

                      AnimatedBuilder(
                        animation: _blinkAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _isLoading
                                ? _blinkAnimation.value * _discsOpacity
                                : _discsOpacity,
                            child: Image.asset(
                              'assets/images/discs.png',
                              height: 80,
                            ),
                          );
                        },
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

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return _ClickBubblyButton(
      text: text,
      color: color,
      onPressed: onPressed,
      animationKey: _animationKey,
    );
  }
}

class _ClickBubblyButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
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
        AnimatedBuilder(
          animation: _clickController,
          builder: (context, child) {
            return Container(
              width: 250,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(50.0),
              ),
              child: child,
            );
          },
          child: MaterialButton(
            onPressed: () {
              _clickController.forward(from: 0);
              if (widget.animationKey?.currentState != null) {
                widget.animationKey!.currentState!.triggerParticleExplosion();
              }
              Future.delayed(
                const Duration(milliseconds: 1200),
                widget.onPressed,
              );
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
