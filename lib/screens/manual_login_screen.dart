import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../services/sound_system.dart';
import '../widgets/animations/loading_button.dart';
import '../widgets/prefetch_overlay_dialog.dart';
import '../theme/app_backgrounds.dart';
import '../providers/theme_mode_provider.dart';
import '../theme/app_text_colors.dart';
import '../theme/app_themes.dart';
import '../widgets/version_control_widget.dart';
import 'package:audioplayers/audioplayers.dart';

class ManualLoginScreen extends StatefulWidget {
  const ManualLoginScreen({super.key});

  @override
  ManualLoginScreenState createState() => ManualLoginScreenState();
}

class ManualLoginScreenState extends State<ManualLoginScreen>
    with TickerProviderStateMixin {
  static const Color manualLoginDarkWidgetBg = Color(0xFF3D3F40);

  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  late AudioPlayer _audioPlayer;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioPlayer();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // Start user prefetch early so admin screens load fast after login
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      AuthProvider.warmUpBackendForLogin();
      unawaited(context.read<UserProvider>().prefetchUsersForLogin());
    });
  }

  void _startBlinking() {
    _blinkController.repeat(reverse: true);
  }

  void _stopBlinking() {
    _blinkController.stop();
    _blinkController.reset();
  }

  Future<void> _playErrorSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/error_1.wav'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _showValidationError(String fieldName, String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color dialogBg = isDark ? const Color(0xFF3D3F40) : Colors.white;
        final Color dialogTextColor = isDark ? Colors.white : Colors.black;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: dialogBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fieldName,
                      style: TextStyle(
                        color: dialogTextColor,
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        color: dialogTextColor,
                        fontFamily: 'Poppins',
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        SoundSystem.playButtonClick();
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
                      child: Text(
                        'OK',
                        style: TextStyle(
                          color: dialogTextColor,
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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _audioPlayer.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLight = !isDark;
    final Color widgetBg = isDark ? manualLoginDarkWidgetBg : Colors.white;
    final Color hintColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(appBackgroundAsset(context)),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/khono.png', height: 100),
                      const SizedBox(height: 48),
                      AnimatedBuilder(
                        animation: _blinkAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _isLoading ? _blinkAnimation.value : 1.0,
                            child: child,
                          );
                        },
                        child: Semantics(
                          label: 'Manual Login',
                          child: Text(
                            'Manual Login',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: appTextColor(context),
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Semantics(
                            label: 'Email Address',
                            child: Text(
                              'Email Address',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: appTextColor(context),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 590,
                            child: TextField(
                              controller: _emailController,
                              style: TextStyle(
                                color: appTextColor(context),
                                fontFamily: 'Poppins',
                              ),
                              decoration: InputDecoration(
                                hintText: 'example@khonology.com',
                                hintStyle: TextStyle(color: hintColor),
                                filled: true,
                                fillColor: widgetBg,
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
                        text: 'LOG IN',
                        color: const Color(0xFFC10D00),

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
                          SoundSystem.playButtonClick();
                          final email = _emailController.text.trim();
                          if (email.isEmpty) {
                            await _playErrorSound();
                            _showValidationError(
                              'Email Required',
                              'Please enter your email address to continue with login.',
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
                            await _playErrorSound();
                            if (!mounted) return;
                            final currentContext = context;
                            if (!currentContext.mounted) return;
                            showDialog(
                              context: currentContext,
                              barrierColor: Colors.black54,
                              builder: (BuildContext context) {
                                final bool isDark =
                                    Theme.of(context).brightness ==
                                    Brightness.dark;
                                final Color dialogBg = isDark
                                    ? const Color(0xFF3D3F40)
                                    : Colors.white;
                                final Color dialogTextColor = isDark
                                    ? Colors.white
                                    : Colors.black;
                                return Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: dialogBg,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Please use your correct work email',
                                              style: TextStyle(
                                                color: dialogTextColor,
                                                fontFamily: 'Poppins',
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Only Khonology work emails (@khonology.com) are allowed.',
                                              style: TextStyle(
                                                color: dialogTextColor,
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 24),
                                            TextButton(
                                              onPressed: () {
                                                SoundSystem.playButtonClick();
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
                                              child: Text(
                                                'OK',
                                                style: TextStyle(
                                                  color: dialogTextColor,
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
                          final themeModeProvider = context
                              .read<ThemeModeProvider>();
                          final navigator = Navigator.of(context);
                          try {
                            final success = await authProvider.manualLogin(
                              normalizedEmail,
                            );
                            if (!mounted) return;
                            if (success) {
                              await themeModeProvider.applyThemePreference(
                                authProvider.userThemePreference,
                              );
                              await _prefetchUsersAndNavigate(
                                // ignore: use_build_context_synchronously
                                context,
                                navigator,
                                authProvider,
                                playLoginSuccessSound: true,
                              );
                            } else {
                              await _playErrorSound();
                              _showValidationError(
                                'Login Failed',
                                'Login failed. Please check your email or try again later.',
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            await _playErrorSound();
                            _showValidationError(
                              'Error',
                              e
                                      .toString()
                                      .replaceFirst('Exception: ', '')
                                      .isNotEmpty
                                  ? e.toString().replaceFirst('Exception: ', '')
                                  : 'Login failed. Please try again.',
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildButton(
                        text: 'BACK',
                        color: Colors.grey,
                        onPressed: () {
                          SoundSystem.playButtonClick();
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(height: 48),
                      Image.asset(
                        Theme.of(context).brightness == Brightness.dark
                            ? 'assets/images/discs.png'
                            : 'assets/images/red_disc.png',
                        height: Theme.of(context).brightness == Brightness.dark
                            ? 72
                            : 110,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 76,
              child: Center(
                child: VersionControlWidget(
                  textColor: isLight ? Colors.black54 : Colors.white70,
                  hoverColor: isLight ? Colors.black : Colors.white,
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Consumer<ThemeModeProvider>(
                  builder: (context, themeMode, _) {
                    return FloatingActionButton(
                      mini: true,
                      shape: const CircleBorder(),
                      heroTag: 'manual_login_theme_toggle_fab',
                      onPressed: () {
                        SoundSystem.playButtonClick();
                        themeMode.toggle();
                      },
                      backgroundColor: AppThemes.light.primaryColor,
                      child: Icon(
                        themeMode.isLight
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: appTextColor(context),
                      ),
                    );
                  },
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
      onPressed: () {
        SoundSystem.playButtonClick();
        onPressed();
      },
    );
  }

  Future<void> _prefetchUsersAndNavigate(
    BuildContext context,
    NavigatorState navigator,
    AuthProvider authProvider, {
    bool playLoginSuccessSound = false,
  }) async {
    if (!mounted) return;
    final dialogContext = context;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext _) => PrefetchOverlayDialog(
        authProvider: authProvider,
        onComplete: () {
          Navigator.of(dialogContext).pop();
          navigator.pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MainScreen(
                    initialIndex: 8,
                    playLoginSuccessSound: playLoginSuccessSound,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 350),
            ),
            (route) => false,
          );
        },
      ),
    );
  }

  Future<void> _handleSpecialAccess(
    BuildContext context,
    String baseEmail,
  ) async {
    final navigator = Navigator.of(context);
    final currentContext = context;
    final authProvider = context.read<AuthProvider>();
    final themeModeProvider = context.read<ThemeModeProvider>();
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final emails = await userProvider.fetchAllUserEmails();

      if (emails.isEmpty) {
        if (!mounted) return;
        _showValidationError(
          'No Users Found',
          'No users found. Please try again.',
        );
        return;
      }

      if (!mounted) return;
      final selectedEmail = await showDialog<String>(
        // ignore: use_build_context_synchronously
        context: currentContext,
        barrierColor: Colors.black54,
        builder: (BuildContext dialogContext) {
          final bool isDark =
              Theme.of(dialogContext).brightness == Brightness.dark;
          final Color dialogBg = isDark
              ? const Color(0xFF2C3E50).withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.95);

          return Dialog(
            backgroundColor: Colors.transparent,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: dialogBg,
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
                    Text(
                      'Select User Email',
                      style: TextStyle(
                        color: appTextColor(dialogContext),
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
                              style: TextStyle(
                                color: appTextColor(context),
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              SoundSystem.playButtonClick();
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
                        SoundSystem.playButtonClick();
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
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: appTextColor(dialogContext),
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
          selectedEmail.trim().toLowerCase(),
          isSpecialAccess: true,
        );

        if (!mounted) return;
        if (success) {
          await themeModeProvider.applyThemePreference(
            authProvider.userThemePreference,
          );
          await _prefetchUsersAndNavigate(
            // ignore: use_build_context_synchronously
            context,
            navigator,
            authProvider,
            playLoginSuccessSound: true,
          );
        } else {
          _showValidationError(
            'Login Failed',
            'Login failed. Please try again.',
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      _showValidationError('Error', 'An error occurred. Please try again.');
    }
  }
}

class _LoadingConfirmButtonWrapper extends StatefulWidget {
  final String text;
  final Color color;
  final Future<void> Function() onPressed;
  final ValueChanged<bool> onLoadingChanged;

  const _LoadingConfirmButtonWrapper({
    required this.text,
    required this.color,
    required this.onPressed,
    required this.onLoadingChanged,
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
        SoundSystem.playButtonClick();

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
  const _ClickBubblyButton({
    required this.text,
    required this.color,
    required this.onPressed,
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
              SoundSystem.playButtonClick();
              _clickController.forward(from: 0);
              widget.onPressed();
            },
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              widget.text,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: appTextColor(context),
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
