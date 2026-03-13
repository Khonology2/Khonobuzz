import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

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
    'Setting up...',
    'Gathering your data...',
    'Loading your profile...',
    'Getting your roles...',
    'Syncing preferences...',
    'Loading modules...',
    'Loading your module roles...',
    'Ready to go!',
    'Logging you in...',
  ];

  static const Duration _messageDuration = Duration(seconds: 3);

  int _currentMessageIndex = 0;
  double _mockProgress = 0.115;
  bool _prefetchSuccess = false;
  bool _prefetchDone = false;
  bool _canShowReady = false;
  bool _showingReady = false;
  Timer? _messageTimer;
  Timer? _finalDelayTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMessageSequence();
      _runPrefetch();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _finalDelayTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startMessageSequence() {
    _messageTimer?.cancel();
    _messageTimer = Timer.periodic(_messageDuration, (_) {
      if (!mounted) return;
      setState(() {
        if (_currentMessageIndex < _progressMessages.length - 1) {
          _currentMessageIndex++;
          _mockProgress = (_currentMessageIndex + 1) / _progressMessages.length * 0.92;
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
    });
  }

  void _tryShowReady() {
    if (!_prefetchDone || !_canShowReady || _showingReady || !mounted) return;
    _showingReady = true;
    _messageTimer?.cancel();
    _finalDelayTimer?.cancel();
    setState(() {
      _prefetchSuccess = true;
      _mockProgress = 1.0;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) widget.onComplete();
    });
  }

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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black54,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_prefetchSuccess)
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 56)
                  else
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Color(0xFFC10D00),
                        strokeWidth: 3,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      final message = _prefetchSuccess
                          ? 'Ready!'
                          : _progressMessages[_currentMessageIndex.clamp(0, _progressMessages.length - 1)];
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          message,
                          key: ValueKey<String>(message),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final barColor = _prefetchSuccess
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFC10D00);
                      final pulseOpacity = 0.2 + 0.25 * _pulseAnimation.value;
                      return Container(
                        width: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withValues(alpha: pulseOpacity),
                              blurRadius: 6 + 4 * _pulseAnimation.value,
                              spreadRadius: 0.5 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: 220,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final fillWidth = constraints.maxWidth * _mockProgress;
                                final barColor = _prefetchSuccess
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFC10D00);
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      width: fillWidth,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: barColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    if (fillWidth > 4)
                                      Positioned(
                                        left: fillWidth - 6,
                                        top: 0,
                                        child: AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, _) {
                                            return Container(
                                              width: 12,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(3),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: barColor.withValues(
                                                      alpha: 0.4 * _pulseAnimation.value,
                                                    ),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
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
          ),
        ),
      ),
    );
  }
}
