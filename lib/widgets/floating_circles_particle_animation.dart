import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingCirclesParticleAnimation extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const FloatingCirclesParticleAnimation({super.key, this.onAnimationComplete});

  @override
  State<FloatingCirclesParticleAnimation> createState() =>
      FloatingCirclesParticleAnimationState();
}

class FloatingCirclesParticleAnimationState
    extends State<FloatingCirclesParticleAnimation>
    with TickerProviderStateMixin {
  late AnimationController _parallaxController;
  late AnimationController _particleController;
  late AnimationController _fadeInController;
  Animation<double> _fadeInOpacity = const AlwaysStoppedAnimation<double>(0.0);
  bool _showParticles = false;
  bool _isExploding = false;
  bool _isDissolving = false;
  late AnimationController _dissolveController;
  Animation<double> _dissolveOpacity = const AlwaysStoppedAnimation<double>(
    1.0,
  );
  List<ParticleData> _particles = [];

  @override
  void initState() {
    super.initState();
    _parallaxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeInOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeInController, curve: Curves.easeIn));
    _dissolveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _dissolveOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dissolveController, curve: Curves.easeOut),
    );
  }

  void triggerParticleExplosion() {
    setState(() {
      _isExploding = true;
    });

    // First, fade in the circles
    _fadeInController.forward(from: 0).then((_) {
      if (!mounted) return;

      final screenSize = MediaQuery.of(context).size;
      final currentTime = _parallaxController.value;

      // Calculate circle positions at the moment of click
      final circle1Pos = Offset(
        120 + (math.sin(currentTime * 2 * math.pi) * 40) + 35,
        180 + (math.cos(currentTime * 2 * math.pi) * 30) + 35,
      );
      final circle2Pos = Offset(
        screenSize.width -
            (140 + (math.sin(currentTime * 2 * math.pi + 1.5) * 50) + 45),
        220 + (math.cos(currentTime * 2 * math.pi + 1.5) * 35) + 45,
      );
      final circle3Pos = Offset(
        200 + (math.sin(currentTime * 2 * math.pi + 3) * 35) + 30,
        screenSize.height -
            (150 + (math.cos(currentTime * 2 * math.pi + 3) * 25) + 30),
      );
      final circle4Pos = Offset(
        screenSize.width -
            (180 + (math.sin(currentTime * 2 * math.pi + 4) * 45) + 40),
        400 + (math.cos(currentTime * 2 * math.pi + 4) * 40) + 40,
      );

      // Generate particles from each circle position
      _particles = [];
      final circlePositions = [circle1Pos, circle2Pos, circle3Pos, circle4Pos];
      final particleCounts = [15, 20, 12, 18];

      for (int i = 0; i < circlePositions.length; i++) {
        final center = circlePositions[i];
        final count = particleCounts[i];
        for (int j = 0; j < count; j++) {
          final angle =
              (j / count) * 2 * math.pi + (math.Random().nextDouble() * 0.5);
          final speed = 150 + (math.Random().nextDouble() * 100);
          _particles.add(
            ParticleData(
              startPosition: center,
              angle: angle,
              speed: speed,
              size: (2 + (math.Random().nextDouble() * 3)) * 2.24,
              opacity: 0.15 + (math.Random().nextDouble() * 0.1),
            ),
          );
        }
      }

      setState(() {
        _showParticles = true;
      });
      _particleController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {
            _showParticles = false;
            _isExploding = false;
            _particles = [];
          });
          if (widget.onAnimationComplete != null) {
            widget.onAnimationComplete!();
          }
        }
      });
    });
  }

  void triggerDissolve() {
    setState(() {
      _isDissolving = true;
    });
    _dissolveController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _isDissolving = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [_buildFloatingShapes(), if (_showParticles) _buildParticles()],
    );
  }

  Widget _buildFloatingShapes() {
    if (_showParticles) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([
        _parallaxController,
        _fadeInController,
        _dissolveController,
      ]),
      builder: (context, child) {
        return Stack(
          children: [
            // Circle 1 - Top Left
            Positioned(
              left:
                  120 +
                  (math.sin(_parallaxController.value * 2 * math.pi) * 40),
              top:
                  180 +
                  (math.cos(_parallaxController.value * 2 * math.pi) * 30),
              child: Transform.rotate(
                angle: _parallaxController.value * 2 * math.pi,
                child: Opacity(
                  opacity: _isExploding
                      ? _fadeInOpacity.value
                      : (_isDissolving ? _dissolveOpacity.value : 1.0),
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.18 *
                            (_isExploding
                                ? _fadeInOpacity.value
                                : (_isDissolving
                                      ? _dissolveOpacity.value
                                      : 1.0)),
                      ),
                    ),
                    size: const Size(70, 70),
                  ),
                ),
              ),
            ),
            // Circle 2 - Top Right
            Positioned(
              right:
                  140 +
                  (math.sin(_parallaxController.value * 2 * math.pi + 1.5) *
                      50),
              top:
                  220 +
                  (math.cos(_parallaxController.value * 2 * math.pi + 1.5) *
                      35),
              child: Transform.rotate(
                angle: -_parallaxController.value * 2 * math.pi * 0.8,
                child: Opacity(
                  opacity: _isExploding
                      ? _fadeInOpacity.value
                      : (_isDissolving ? _dissolveOpacity.value : 1.0),
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.20 *
                            (_isExploding
                                ? _fadeInOpacity.value
                                : (_isDissolving
                                      ? _dissolveOpacity.value
                                      : 1.0)),
                      ),
                    ),
                    size: const Size(90, 90),
                  ),
                ),
              ),
            ),
            // Circle 3 - Bottom Left
            Positioned(
              left:
                  200 +
                  (math.sin(_parallaxController.value * 2 * math.pi + 3) * 35),
              bottom:
                  150 +
                  (math.cos(_parallaxController.value * 2 * math.pi + 3) * 25),
              child: Transform.rotate(
                angle: _parallaxController.value * 2 * math.pi * 0.6,
                child: Opacity(
                  opacity: _isExploding
                      ? _fadeInOpacity.value
                      : (_isDissolving ? _dissolveOpacity.value : 1.0),
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.15 *
                            (_isExploding
                                ? _fadeInOpacity.value
                                : (_isDissolving
                                      ? _dissolveOpacity.value
                                      : 1.0)),
                      ),
                    ),
                    size: const Size(60, 60),
                  ),
                ),
              ),
            ),
            // Circle 4 - Center Right
            Positioned(
              right:
                  180 +
                  (math.sin(_parallaxController.value * 2 * math.pi + 4) * 45),
              top:
                  400 +
                  (math.cos(_parallaxController.value * 2 * math.pi + 4) * 40),
              child: Transform.rotate(
                angle: -_parallaxController.value * 2 * math.pi * 0.7,
                child: Opacity(
                  opacity: _isExploding
                      ? _fadeInOpacity.value
                      : (_isDissolving ? _dissolveOpacity.value : 1.0),
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.18 *
                            (_isExploding
                                ? _fadeInOpacity.value
                                : (_isDissolving
                                      ? _dissolveOpacity.value
                                      : 1.0)),
                      ),
                    ),
                    size: const Size(80, 80),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticleExplosionPainter(
            particles: _particles,
            progress: _particleController.value,
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }

  @override
  void dispose() {
    _parallaxController.dispose();
    _particleController.dispose();
    _fadeInController.dispose();
    _dissolveController.dispose();
    super.dispose();
  }
}

class ParticleData {
  final Offset startPosition;
  final double angle;
  final double speed;
  final double size;
  final double opacity;

  ParticleData({
    required this.startPosition,
    required this.angle,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

class ParticleExplosionPainter extends CustomPainter {
  final List<ParticleData> particles;
  final double progress;

  ParticleExplosionPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final distance = particle.speed * progress;
      final x = particle.startPosition.dx + math.cos(particle.angle) * distance;
      final y = particle.startPosition.dy + math.sin(particle.angle) * distance;

      final currentOpacity = particle.opacity * (1.0 - progress);
      final currentSize = particle.size * (1.0 - progress * 0.5);

      paint.color = const Color(0xFFC10D00).withValues(alpha: currentOpacity);
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleExplosionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles.length != particles.length;
  }
}

class CirclePainter extends CustomPainter {
  final Color color;

  CirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
