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
  late AnimationController _spinController;
  late AnimationController _morphController;
  late AnimationController _fadeInController;
  Animation<double> _fadeInOpacity = const AlwaysStoppedAnimation<double>(0.0);
  bool _showParticles = false;
  bool _isExploding = false;
  bool _isDissolving = false;
  bool _isMorphing = false;
  bool _isSpinning = false;
  late AnimationController _dissolveController;
  Animation<double> _dissolveOpacity = const AlwaysStoppedAnimation<double>(
    1.0,
  );
  List<ParticleData> _particles = [];
  List<LightStreakData> _streaks = [];
  List<MorphParticleData> _morphParticles = [];
  List<CircleConfig> _circleConfigs = [];

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
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
    if (_isExploding || _isMorphing || _isSpinning || _showParticles) {
      return;
    }

    _spinController.stop();
    _spinController.reset();
    _particleController.stop();
    _particleController.reset();
    _fadeInController.stop();
    _fadeInController.reset();
    _dissolveController.stop();
    _dissolveController.reset();
    _morphController.stop();
    _morphController.reset();
    setState(() {
      _isExploding = true;
      _isMorphing = false;
      _showParticles = false;
      _particles = [];
      _streaks = [];
      _morphParticles = [];
      _circleConfigs = [];
      _isSpinning = true;
    });

    _spinController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _isSpinning = false;
      });
      _fadeInController.forward(from: 0).then((_) {
        if (!mounted) return;

        final screenSize = MediaQuery.of(context).size;
        final currentTime = _parallaxController.value;

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

        _particles = [];
        final circlePositions = [
          circle1Pos,
          circle2Pos,
          circle3Pos,
          circle4Pos,
        ];
        final particleCounts = [15, 20, 12, 18];
        const circleSizes = [70.0, 90.0, 60.0, 80.0];
        _circleConfigs = List.generate(
          circlePositions.length,
          (index) => CircleConfig(
            center: circlePositions[index],
            size: circleSizes[index],
          ),
        );

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

        _streaks = [];
        final screenCenter =
            Offset(screenSize.width / 2, screenSize.height / 2);
        for (final center in circlePositions) {
          final dirX = center.dx >= screenCenter.dx ? 1.0 : -1.0;
          final dirY = center.dy >= screenCenter.dy ? 1.0 : -1.0;
          final rawDirection = Offset(dirX, dirY);
          final length = math.sqrt(rawDirection.dx * rawDirection.dx +
              rawDirection.dy * rawDirection.dy);
          final direction =
              length == 0 ? const Offset(1, 1) : rawDirection / length;
          final distance = screenSize.longestSide * 0.85;
          final target = center + direction * distance;
          final opacity = 0.6 + (math.Random().nextDouble() * 0.2);
          final width = 2.0 + (math.Random().nextDouble() * 2.0);
          _streaks.add(
            LightStreakData(
              start: center,
              end: target,
              baseOpacity: opacity,
              strokeWidth: width,
            ),
          );
        }

        setState(() {
          _showParticles = true;
        });
        _particleController.forward(from: 0).then((_) {
          if (!mounted) return;
          _startMorphFromParticles();
        });
      });
    });
  }

  void _startMorphFromParticles() {
    if (_circleConfigs.isEmpty) {
      setState(() {
        _showParticles = false;
        _isExploding = false;
        _particles = [];
        _streaks = [];
      });
      if (widget.onAnimationComplete != null) {
        widget.onAnimationComplete!();
      }
      return;
    }

    final random = math.Random();
    final List<MorphParticleData> morphParticles = [];

    for (final circle in _circleConfigs) {
      final baseRadius = circle.size / 2;
      const count = 18;
      for (int i = 0; i < count; i++) {
        final startRadius = baseRadius * (1.2 + random.nextDouble() * 1.2);
        final initialAngle = random.nextDouble() * 2 * math.pi;
        final size = 2.0 + random.nextDouble() * 2.5;
        final opacity = 0.2 + random.nextDouble() * 0.25;
        morphParticles.add(
          MorphParticleData(
            center: circle.center,
            startRadius: startRadius,
            initialAngle: initialAngle,
            size: size,
            opacity: opacity,
          ),
        );
      }
    }

    setState(() {
      _particles = [];
      _streaks = [];
      _morphParticles = morphParticles;
      _isMorphing = true;
      _showParticles = true;
    });

    _morphController.forward(from: 0).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMorphing = false;
        _showParticles = false;
        _morphParticles = [];
        _isExploding = false;
      });
      if (widget.onAnimationComplete != null) {
        widget.onAnimationComplete!();
      }
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
      children: [
        _buildFloatingShapes(),
        if (_showParticles && !_isMorphing) _buildParticles(),
        if (_showParticles && !_isMorphing && _streaks.isNotEmpty)
          _buildStreaks(),
        if (_isMorphing) _buildMorphParticles(),
        if (_isMorphing) _buildMorphCircles(),
      ],
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
        final screenSize = MediaQuery.of(context).size;
        final t = _parallaxController.value;
        final spinT = _isSpinning ? _spinController.value : 0.0;
        const spinAmount = 6 * math.pi;

        final circle1Center = Offset(
          120 + (math.sin(t * 2 * math.pi) * 40) + 35,
          180 + (math.cos(t * 2 * math.pi) * 30) + 35,
        );
        final circle2Center = Offset(
          screenSize.width -
              (140 + (math.sin(t * 2 * math.pi + 1.5) * 50) + 45),
          220 + (math.cos(t * 2 * math.pi + 1.5) * 35) + 45,
        );
        final circle3Center = Offset(
          200 + (math.sin(t * 2 * math.pi + 3) * 35) + 30,
          screenSize.height -
              (150 + (math.cos(t * 2 * math.pi + 3) * 25) + 30),
        );
        final circle4Center = Offset(
          screenSize.width -
              (180 + (math.sin(t * 2 * math.pi + 4) * 45) + 40),
          400 + (math.cos(t * 2 * math.pi + 4) * 40) + 40,
        );

        const r1 = 35.0;
        const r2 = 45.0;
        const r3 = 30.0;
        const r4 = 40.0;

        final adjusted1 = _applyBounce(circle1Center, r1, screenSize);
        final adjusted2 = _applyBounce(circle2Center, r2, screenSize);
        final adjusted3 = _applyBounce(circle3Center, r3, screenSize);
        final adjusted4 = _applyBounce(circle4Center, r4, screenSize);

        return Stack(
          children: [
            // Circle 1 - Top Left
            Positioned(
              left: adjusted1.dx - r1,
              top: adjusted1.dy - r1,
              child: Transform.rotate(
                angle: (t * 2 * math.pi) + (spinT * spinAmount),
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
              left: adjusted2.dx - r2,
              top: adjusted2.dy - r2,
              child: Transform.rotate(
                angle: (-t * 2 * math.pi * 0.8) - (spinT * spinAmount),
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
              left: adjusted3.dx - r3,
              top: adjusted3.dy - r3,
              child: Transform.rotate(
                angle: (t * 2 * math.pi * 0.6) + (spinT * spinAmount),
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
              left: adjusted4.dx - r4,
              top: adjusted4.dy - r4,
              child: Transform.rotate(
                angle: (-t * 2 * math.pi * 0.7) - (spinT * spinAmount),
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

  Widget _buildMorphParticles() {
    return AnimatedBuilder(
      animation: _morphController,
      builder: (context, child) {
        return CustomPaint(
          painter: MorphParticlesPainter(
            particles: _morphParticles,
            progress: _morphController.value,
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }

  Widget _buildMorphCircles() {
    return AnimatedBuilder(
      animation: _morphController,
      builder: (context, child) {
        return CustomPaint(
          painter: MorphingCirclesPainter(
            circles: _circleConfigs,
            progress: _morphController.value,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }

  Widget _buildStreaks() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return CustomPaint(
          painter: LightStreaksPainter(
            streaks: _streaks,
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
    _spinController.dispose();
    _morphController.dispose();
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

class LightStreakData {
  final Offset start;
  final Offset end;
  final double baseOpacity;
  final double strokeWidth;

  LightStreakData({
    required this.start,
    required this.end,
    required this.baseOpacity,
    required this.strokeWidth,
  });
}

class MorphParticleData {
  final Offset center;
  final double startRadius;
  final double initialAngle;
  final double size;
  final double opacity;

  MorphParticleData({
    required this.center,
    required this.startRadius,
    required this.initialAngle,
    required this.size,
    required this.opacity,
  });
}

class CircleConfig {
  final Offset center;
  final double size;

  CircleConfig({
    required this.center,
    required this.size,
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

Offset _applyBounce(Offset center, double radius, Size screenSize) {
  final obstacle = Rect.fromCenter(
    center: Offset(screenSize.width / 2, screenSize.height * 0.5),
    width: screenSize.width * 0.6,
    height: screenSize.height * 0.6,
  );

  final inflated = obstacle.inflate(radius);
  if (!inflated.contains(center)) {
    return center;
  }

  final obstacleCenter = obstacle.center;
  final dx = center.dx - obstacleCenter.dx;
  final dy = center.dy - obstacleCenter.dy;

  if (dx == 0 && dy == 0) {
    return Offset(center.dx, center.dy - (obstacle.height / 2 + radius));
  }

  final angle = math.atan2(dy, dx);
  final halfWidth = obstacle.width / 2 + radius;
  final halfHeight = obstacle.height / 2 + radius;
  final px = math.cos(angle) * halfWidth;
  final py = math.sin(angle) * halfHeight;

  return Offset(obstacleCenter.dx + px, obstacleCenter.dy + py);
}

class LightStreaksPainter extends CustomPainter {
  final List<LightStreakData> streaks;
  final double progress;

  LightStreaksPainter({required this.streaks, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || streaks.isEmpty) return;
    final eased = Curves.easeOutQuad.transform(progress.clamp(0.0, 1.0));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final streak in streaks) {
      final end = Offset.lerp(streak.start, streak.end, eased)!;
      final tailStart =
          Offset.lerp(streak.start, end, (eased - 0.35).clamp(0.0, 1.0))!;
      final opacity = streak.baseOpacity * (1.0 - eased);
      if (opacity <= 0) continue;
      paint
        ..color = const Color(0xFFC10D00).withValues(alpha: opacity)
        ..strokeWidth = streak.strokeWidth;
      canvas.drawLine(tailStart, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LightStreaksPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.streaks.length != streaks.length;
  }
}

class MorphParticlesPainter extends CustomPainter {
  final List<MorphParticleData> particles;
  final double progress;

  MorphParticlesPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty || progress <= 0) {
      return;
    }

    final t = Curves.easeInOut.transform(progress.clamp(0.0, 1.0));
    final paint = Paint()..style = PaintingStyle.fill;
    const turns = 2.5;

    for (final particle in particles) {
      final radius = particle.startRadius * (1.0 - t);
      final angle = particle.initialAngle + turns * 2 * math.pi * t;
      final x = particle.center.dx + math.cos(angle) * radius;
      final y = particle.center.dy + math.sin(angle) * radius;

      final opacity = particle.opacity * (1.0 - t * 0.7);
      if (opacity <= 0) {
        continue;
      }

      paint.color = const Color(0xFFC10D00).withValues(alpha: opacity);
      final currentSize = particle.size * (1.0 - t * 0.3);
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MorphParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles.length != particles.length;
  }
}

class MorphingCirclesPainter extends CustomPainter {
  final List<CircleConfig> circles;
  final double progress;
  final Color color;

  MorphingCirclesPainter({
    required this.circles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (circles.isEmpty || progress <= 0) {
      return;
    }

    final t = progress.clamp(0.0, 1.0);
    final arcFill = Curves.easeOut.transform(t);
    final dottedOpacity = (1.0 - t).clamp(0.0, 1.0);
    final solidOpacity = Curves.easeIn.transform(t);
    const baseSweep = math.pi * 1.42;
    const startAngle = -math.pi * 0.75;
    final sweep = baseSweep * arcFill;

    for (final circle in circles) {
      final maxRadius = circle.size / 2;
      final strokeWidth = maxRadius * 0.45;
      final radius = maxRadius - strokeWidth / 2;
      final rect = Rect.fromCircle(center: circle.center, radius: radius);

      if (dottedOpacity > 0) {
        final dottedPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: dottedOpacity * 0.9);

        const totalDots = 40;
        final dotsToDraw = (totalDots * arcFill).clamp(1, totalDots).toInt();
        for (int i = 0; i < dotsToDraw; i++) {
          final dotT =
              dotsToDraw <= 1 ? 0.0 : i / (dotsToDraw - 1).clamp(1, dotsToDraw);
          final angle = startAngle + sweep * dotT;
          final offset = Offset(
            circle.center.dx + math.cos(angle) * radius,
            circle.center.dy + math.sin(angle) * radius,
          );
          final dotRadius = strokeWidth * 0.3;
          canvas.drawCircle(offset, dotRadius, dottedPaint);
        }
      }

      if (solidOpacity > 0) {
        final solidPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..color = color.withValues(alpha: solidOpacity);
        canvas.drawArc(rect, startAngle, sweep, false, solidPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MorphingCirclesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.circles.length != circles.length ||
        oldDelegate.color != color;
  }
}

class CirclePainter extends CustomPainter {
  final Color color;

  CirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final strokeWidth = maxRadius * 0.45;
    final radius = maxRadius - strokeWidth / 2;
    paint.strokeWidth = strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi * 0.75;
    const sweepAngle = math.pi * 1.42;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant CirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
