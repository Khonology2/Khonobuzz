import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'auth_screen.dart';

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
  late AnimationController _parallaxController;
  late AnimationController _particleController;
  late AnimationController _fadeInController;
  Animation<double> _fadeInOpacity = const AlwaysStoppedAnimation<double>(0.0);
  bool _showParticles = false;
  bool _isExploding = false;
  List<ParticleData> _particles = [];

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
            _buildFloatingShapes(),
            if (_showParticles) _buildParticles(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingShapes() {
    if (_showParticles) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_parallaxController, _fadeInController]),
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
                  opacity: _isExploding ? _fadeInOpacity.value : 1.0,
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.18 * (_isExploding ? _fadeInOpacity.value : 1.0),
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
                  opacity: _isExploding ? _fadeInOpacity.value : 1.0,
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.20 * (_isExploding ? _fadeInOpacity.value : 1.0),
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
                  opacity: _isExploding ? _fadeInOpacity.value : 1.0,
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.15 * (_isExploding ? _fadeInOpacity.value : 1.0),
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
                  opacity: _isExploding ? _fadeInOpacity.value : 1.0,
                  child: CustomPaint(
                    painter: CirclePainter(
                      color: Colors.white.withValues(
                        alpha:
                            0.18 * (_isExploding ? _fadeInOpacity.value : 1.0),
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
          _triggerParticleExplosion();
          if (onPressed != null) {
            Future.delayed(const Duration(milliseconds: 1200), onPressed);
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

  void _triggerParticleExplosion() {
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
              size: 2 + (math.Random().nextDouble() * 3),
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
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _btnController.dispose();
    _clickController.dispose();
    _parallaxController.dispose();
    _particleController.dispose();
    _fadeInController.dispose();
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

      paint.color = Colors.white.withValues(alpha: currentOpacity);
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleExplosionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles.length != particles.length;
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
