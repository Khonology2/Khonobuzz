import 'package:flutter/material.dart';
import '../services/sound_system.dart';
import 'auth_screen.dart';
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart';
import 'package:video_player/video_player.dart';

class LobbyScreen extends StatefulWidget {
  final FlutterAadOauth? oauth;
  const LobbyScreen({super.key, this.oauth});

  @override
  LobbyScreenState createState() => LobbyScreenState();
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
              SoundSystem.playButtonClick();
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: Colors.white,
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

class LobbyScreenState extends State<LobbyScreen> {
  double _discsOpacity = 0.0;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _videoController =
        VideoPlayerController.asset('assets/images/animated_rocket.mp4')
          ..setLooping(true)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _videoController?.play();
              });
            }
          });

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/nathi_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((_videoController?.value.isInitialized ?? false))
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 2),
                          ),
                          child: ClipOval(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController?.value.size.width ?? 0,
                                height:
                                    _videoController?.value.size.height ?? 0,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 72),
                      const SizedBox(height: 24),
                      Image.asset('assets/images/khono.png', height: 100),
                      const SizedBox(height: 16),
                      const Text(
                        'Please be patient while Khonology Admin attends to your onboarding request...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AnimatedBubblyButton(
                        text: 'Go Back',
                        color: const Color(0xFFC10D00),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const AuthScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        },
                        bounceDelayMs: 250,
                      ),
                      const SizedBox(height: 32),
                      AnimatedOpacity(
                        opacity: _discsOpacity,
                        duration: const Duration(milliseconds: 1000),
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Image.asset(
                            'assets/videos/spinning_discs.gif',
                            height: 122,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
