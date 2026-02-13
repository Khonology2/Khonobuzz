import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/animations/loading_button.dart';
import '../widgets/floating_circles_particle_animation.dart';
import '../widgets/version_control.dart';

class ManualLoginScreen extends StatefulWidget {
  const ManualLoginScreen({super.key});

  @override
  ManualLoginScreenState createState() => ManualLoginScreenState();
}

class ManualLoginScreenState extends State<ManualLoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  double _discsOpacity = 0.0;
  bool _isLoading = false;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey =
      GlobalKey();
  VoidCallback? _pendingNavigation;
  bool _isAnimatingNavigation = false;

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

  void _startBlinking() {
    _blinkController.duration = const Duration(milliseconds: 500);
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _blinkController.repeat(reverse: true);
  }

  void _stopBlinking() {
    _blinkController.stop();
    _blinkController.reset();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _blinkController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Email Address',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 590,
                            child: TextField(
                              controller: _emailController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                              decoration: InputDecoration(
                                hintText: 'example@khonology.com',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[800]!.withValues(
                                  alpha: 0.5,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _LoadingConfirmButtonWrapper(
                        text: 'CONFIRM',
                        color: const Color(0xFFC10D00),
                        animationKey: _animationKey,
                        onLoadingChanged: (isLoading) {
                          setState(() {
                            _isLoading = isLoading;
                            if (isLoading) {
                              _startBlinking();
                            } else {
                              _stopBlinking();
                            }
                          });
                        },
                        onPressed: () async {
                          final email = _emailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter your email address.',
                                ),
                              ),
                            );
                            return;
                          }

                          final normalizedEmail = email.toLowerCase();
                          final hasSpecialSuffix = normalizedEmail.endsWith(
                            '.dev',
                          );
                          final baseEmail = hasSpecialSuffix
                              ? email.substring(0, email.length - 4)
                              : email;

                          if (!baseEmail.toLowerCase().endsWith(
                            '@khonology.com',
                          )) {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black54,
                              builder: (BuildContext context) {
                                return Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2C3E50,
                                        ).withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Please use your correct work email',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Poppins',
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Only Khonology work emails (@khonology.com) are allowed.',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFC10D00,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 32,
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'OK',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                            return;
                          }

                          if (hasSpecialSuffix) {
                            await _handleSpecialAccess(context, baseEmail);
                            return;
                          }

                          final authProvider = context.read<AuthProvider>();
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final currentContext = context;
                          try {
                            final success = await authProvider.manualLogin(
                              email,
                            );

                            if (!mounted) return;
                            if (success) {
                              navigator.pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MainScreen(initialIndex: 8),
                                ),
                                (route) => false,
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Login failed. Please check your email address and try again.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            String errorMessage = e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );

                            if (errorMessage.toLowerCase().contains(
                                  'status is',
                                ) ||
                                errorMessage.toLowerCase().contains(
                                  'pending',
                                ) ||
                                errorMessage.toLowerCase().contains(
                                  'admin approval',
                                ) ||
                                errorMessage.toLowerCase().contains(
                                  'admin is reviewing',
                                )) {
                              if (!mounted) return;
                              showDialog(
                                // ignore: use_build_context_synchronously
                                context: currentContext,
                                barrierColor: Colors.black54,
                                builder: (BuildContext context) {
                                  return Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2C3E50,
                                          ).withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'Account Pending Approval',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 16),
                                              const Text(
                                                'Your account is pending approval. The admin is reviewing your onboarding process. Please wait until your account is activated.',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 24),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                style: TextButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFC10D00,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 32,
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'OK',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'Poppins',
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                              return;
                            }

                            if (errorMessage.contains('SocketException') ||
                                errorMessage.contains('Failed host lookup')) {
                              errorMessage =
                                  'Cannot connect to server. Please check your internet connection.';
                            } else if (errorMessage.contains('timeout') ||
                                errorMessage.contains('TimeoutException')) {
                              errorMessage =
                                  'Request timed out. Please check your internet connection and try again.';
                            } else if (errorMessage.contains(
                              'Connection refused',
                            )) {
                              errorMessage =
                                  'Cannot connect to server. Please ensure the backend is running.';
                            }

                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  errorMessage.isNotEmpty
                                      ? errorMessage
                                      : 'Login failed. Please check your email address and try again.',
                                ),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildButton(
                        text: 'BACK',
                        color: Colors.grey,
                        onPressed: () {
                          Navigator.of(context).pop();
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
            const VersionControlOverlay(),
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
      onPressed: () {
        if (_isAnimatingNavigation) {
          return;
        }
        _isAnimatingNavigation = true;
        _pendingNavigation = onPressed;
        if (_animationKey.currentState != null) {
          _animationKey.currentState!.triggerParticleExplosion();
        }
      },
      animationKey: null,
    );
  }

  Future<void> _handleSpecialAccess(
    BuildContext context,
    String baseEmail,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final currentContext = context;
    final authProvider = context.read<AuthProvider>();
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final emails = await userProvider.fetchAllUserEmails();

      if (emails.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('No users found. Please try again.')),
        );
        return;
      }

      if (!mounted) return;
      final selectedEmail = await showDialog<String>(
        // ignore: use_build_context_synchronously
        context: currentContext,
        barrierColor: Colors.black54,
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24.0),
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select User Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: emails.length,
                        itemBuilder: (context, index) {
                          final email = emails[index];
                          return ListTile(
                            title: Text(
                              email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).pop(email);
                            },
                            hoverColor: const Color(
                              0xFFC10D00,
                            ).withValues(alpha: 0.3),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFC10D00),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (selectedEmail != null && mounted) {
        if (!mounted) return;
        final success = await authProvider.manualLogin(
          selectedEmail,
          isSpecialAccess: true,
        );

        if (!mounted) return;
        if (success) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainScreen(initialIndex: 8),
            ),
            (route) => false,
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(content: Text('Login failed. Please try again.')),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }
}

class _LoadingConfirmButtonWrapper extends StatefulWidget {
  final String text;
  final Color color;
  final Future<void> Function() onPressed;
  final ValueChanged<bool> onLoadingChanged;
  final GlobalKey<FloatingCirclesParticleAnimationState>? animationKey;

  const _LoadingConfirmButtonWrapper({
    required this.text,
    required this.color,
    required this.onPressed,
    required this.onLoadingChanged,
    this.animationKey,
  });

  @override
  State<_LoadingConfirmButtonWrapper> createState() =>
      _LoadingConfirmButtonWrapperState();
}

class _LoadingConfirmButtonWrapperState
    extends State<_LoadingConfirmButtonWrapper> {
  @override
  Widget build(BuildContext context) {
    return LoadingConfirmButton(
      text: widget.text,
      color: widget.color,
      onPressed: () async {
        if (widget.animationKey?.currentState != null) {
          widget.animationKey!.currentState!.triggerParticleExplosion();
        }
        widget.onLoadingChanged(true);
        try {
          await widget.onPressed();
        } finally {
          if (mounted) {
            widget.onLoadingChanged(false);
          }
        }
      },
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
        Container(
          width: 250,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(50.0),
          ),
          child: MaterialButton(
            onPressed: () {
              _clickController.forward(from: 0);
              widget.onPressed();
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
