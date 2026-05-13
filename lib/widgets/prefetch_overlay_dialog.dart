import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_text_colors.dart';

/// Loading overlay shown after successful login for all users (admin and staff).
/// Displays progress messages, then "Enjoy your session, {name}!" and navigates to main app.
class PrefetchOverlayDialog extends StatefulWidget {
  const PrefetchOverlayDialog({
    super.key,
    required this.authProvider,
    required this.onComplete,
  });

  final AuthProvider authProvider;
  final VoidCallback onComplete;

  @override
  State<PrefetchOverlayDialog> createState() => _PrefetchOverlayDialogState();
}

class _PrefetchOverlayDialogState extends State<PrefetchOverlayDialog>
    with TickerProviderStateMixin {
  static const List<String> _progressMessages = [
    'Getting ready...',
    'Authenticating...',
    'Setting theme preferences...',
    'Loading your profile...',
    'Loading your modules...',
    'Loading your module roles...',
    'Logging you in...',
  ];

  static const Duration _messageDuration = Duration(milliseconds: 2500);
  static const Duration _messageOutDuration = Duration(milliseconds: 420);
  static const Duration _messageInDuration = Duration(milliseconds: 400);

  TextStyle get _messageStyle => TextStyle(
        color: appTextColor(context),
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'Poppins',
      );

  String get _welcomeMessage {
    final name = widget.authProvider.userDisplayName.trim();
    return name.isEmpty
        ? 'Enjoy your session!'
        : 'Enjoy your session, $name!';
  }

  int _currentMessageIndex = 0;
  int _displayedMessageIndex = 0;
  bool _isMaterializing = false;
  bool _isDropping = false;
  bool _prefetchSuccess = false;
  bool _prefetchDone = false;
  bool _canShowReady = false;
  bool _showingReady = false;
  Timer? _messageTimer;
  Timer? _finalDelayTimer;
  late AnimationController _loaderController;
  late AnimationController _messageOutController;
  late AnimationController _messageInController;

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _messageOutController = AnimationController(
      vsync: this,
      duration: _messageOutDuration,
    );
    _messageInController = AnimationController(
      vsync: this,
      duration: _messageInDuration,
    );
    _messageOutController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _displayedMessageIndex = _currentMessageIndex;
          _isMaterializing = false;
          _isDropping = true;
        });
        _messageInController.forward(from: 0);
      }
    });
    _messageInController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _isDropping = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMessageSequence();
      _runPrefetch();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _finalDelayTimer?.cancel();
    _loaderController.dispose();
    _messageOutController.dispose();
    _messageInController.dispose();
    super.dispose();
  }

  void _startMessageSequence() {
    _messageTimer?.cancel();
    _messageTimer = Timer.periodic(_messageDuration, (_) {
      if (!mounted) return;
      if (_currentMessageIndex < _progressMessages.length - 1) {
        setState(() {
          _currentMessageIndex++;
          _isMaterializing = true;
        });
        _messageOutController.forward(from: 0);
      } else {
        _messageTimer?.cancel();
        _finalDelayTimer?.cancel();
        _finalDelayTimer = Timer(_messageDuration, () {
          if (!mounted) return;
          setState(() => _canShowReady = true);
          _tryShowReady();
        });
      }
    });
  }

  static const double _messageMaxWidth = 304; // 360 - 56 padding

  List<Offset> _getCharacterOffsets(String message) {
    final painter = TextPainter(
      text: TextSpan(text: message, style: _messageStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: _messageMaxWidth);
    final offsets = <Offset>[];
    for (var i = 0; i < message.length; i++) {
      offsets.add(painter.getOffsetForCaret(TextPosition(offset: i), Rect.zero));
    }
    return offsets;
  }

  Widget _buildMessageTransition() {
    final message = _progressMessages[_displayedMessageIndex.clamp(0, _progressMessages.length - 1)];
    final text = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _messageMaxWidth),
      child: Text(
        message,
        style: _messageStyle,
        maxLines: 2,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
      ),
    );
    if (_isMaterializing) {
      return _buildParticleMaterialize(message);
    }
    if (_isDropping) {
      return FadeTransition(
        opacity: _messageInController.drive(
          Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.easeOut)),
        ),
        child: SlideTransition(
          position: _messageInController.drive(
            Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: text,
        ),
      );
    }
    return text;
  }

  Widget _buildParticleMaterialize(String message) {
    final offsets = _getCharacterOffsets(message);
    if (offsets.isEmpty) return const SizedBox.shrink();
    final painter = TextPainter(
      text: TextSpan(text: message, style: _messageStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: _messageMaxWidth);
    final size = painter.size;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: AnimatedBuilder(
        animation: _messageOutController,
        builder: (context, _) {
          final t = Curves.easeIn.transform(_messageOutController.value);
          return Stack(
            clipBehavior: Clip.none,
            children: List.generate(message.length, (i) {
              final dx = ((i * 31) % 37) - 18.0;
              final dy = ((i * 17) % 29) - 14.0;
              final scatter = 1.0 - t;
              final x = offsets[i].dx + dx * scatter;
              final y = offsets[i].dy + dy * scatter;
              final opacity = (1.0 - t).clamp(0.0, 1.0);
              final scale = 1.0 - 0.4 * t;
              return Positioned(
                left: x,
                top: y,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: Text(
                      message.substring(i, i + 1),
                      style: _messageStyle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  void _tryShowReady() {
    if (!_prefetchDone || !_canShowReady || _showingReady || !mounted) return;
    _showingReady = true;
    _messageTimer?.cancel();
    _finalDelayTimer?.cancel();
    setState(() {
      _prefetchSuccess = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) widget.onComplete();
    });
  }

  /// All users (admin and staff) go through this dialog. Only admin runs user-list prefetch.
  Future<void> _runPrefetch() async {
    try {
      final role = (widget.authProvider.userRole ?? '').toLowerCase();
      if (role == 'admin') {
        await context.read<UserProvider>().prefetchUsersForLogin(forceRefresh: true);
      }
      if (!mounted) return;
      _prefetchDone = true;
      _tryShowReady();
    } catch (_) {
      if (mounted) {
        _prefetchDone = true;
        _tryShowReady();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelBg = isDark ? const Color(0xFF3D3F40) : Colors.white;
    final Color overlayBg = isDark
        ? Colors.black54
        : Colors.black.withValues(alpha: 0.12);
    final Color shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.12);
    final Color loaderBlueColor = isDark
        ? const Color.fromARGB(255, 253, 254, 255)
        : Colors.black.withValues(alpha: 0.6);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: overlayBg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: panelBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_prefetchSuccess)
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 56),
                  if (_prefetchSuccess) const SizedBox(height: 20),
                  Center(
                    child: _prefetchSuccess
                        ? Text(
                            _welcomeMessage,
                            style: _messageStyle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          )
                        : _buildMessageTransition(),
                  ),
                  const SizedBox(height: 20),
                  if (_prefetchSuccess)
                    const SizedBox(height: 50)
                  else
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: AnimatedBuilder(
                        animation: _loaderController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(50, 50),
                            painter: _LoaderPainter(
                              _loaderController.value * 2 * math.pi,
                              blueColor: loaderBlueColor,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  _LoaderPainter(this.angle, {required this.blueColor});

  final double angle;
  final Color blueColor;

  static const double _size = 50;
  static const double _strokeWidth = 8;
  static const double _radius = (_size / 2) - (_strokeWidth / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: _radius);

    final redPaint = Paint()
      ..color = const Color(0xFFC10D00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    final bluePaint = Paint()
      ..color = blueColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(rect, 0, math.pi / 2, false, redPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-angle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(rect, math.pi, math.pi / 2, false, bluePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
