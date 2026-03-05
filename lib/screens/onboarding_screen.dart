import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/sound_system.dart';
import '../widgets/animations/loading_button.dart';
import '../widgets/floating_circles_particle_animation.dart';
import 'lobby_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final FlutterAadOauth? oauth;
  const OnboardingScreen({super.key, this.oauth});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  double _discsOpacity = 0.0;
  bool _isLoading = false;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey =
      GlobalKey();

  late AudioPlayer _audioPlayer;

  final List<String> _departments = const [
    'Management',
    'Operations',
    'Finance',
    'HR',
    'Sales',
  ];
  String? _selectedDepartment;

  final List<String> _designations = const [
    'Director',
    'Developer',
    'Support Analyst',
    'Learner',
    'UX Designer',
    'AWS Cloud Engineer',
    'Tester',
    'RMB Small Talk Developer',
    'Finance',
    'Business Analyst',
    'Manager',
    'Delivery Manager',
    'Analyst',
    'Sales Person',
    'HR',
    'Junior Analyst',
  ];
  String? _selectedDesignation;

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

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _blinkController.dispose();
    _audioPlayer.dispose();

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
                      const Text(
                        'Create Your Account',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 32),

                      Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxWidth = constraints.maxWidth > 0
                                ? constraints.maxWidth.clamp(0.0, 590.0)
                                : 590.0;
                            final isNarrow = maxWidth < 590;

                            if (isNarrow || constraints.maxWidth < 600) {
                              return SizedBox(
                                width: maxWidth,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildTextField(
                                            label: 'First Name',
                                            controller: _firstNameController,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildTextField(
                                            label: 'Email Address',
                                            hintText: 'example@khonology.com',
                                            controller: _emailController,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildTextField(
                                            label: 'Last Name',
                                            controller: _lastNameController,
                                          ),
                                          const SizedBox(height: 16),

                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Department',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              DropdownButtonFormField<String>(
                                                initialValue:
                                                    _selectedDepartment,
                                                dropdownColor: Colors.grey[800],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                ),
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  fillColor: Colors.grey[800]!
                                                      .withValues(alpha: 0.5),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          25.0,
                                                        ),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 12.0,
                                                      ),
                                                ),
                                                hint: Text(
                                                  'Select Department',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                items: _departments.map((
                                                  String department,
                                                ) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: department,
                                                    child: Text(department),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    _selectedDepartment =
                                                        newValue;
                                                  });
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please select a department';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return SizedBox(
                                width: maxWidth,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildTextField(
                                            label: 'First Name',
                                            controller: _firstNameController,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildTextField(
                                            label: 'Email Address',
                                            hintText: 'example@khonology.com',
                                            controller: _emailController,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildTextField(
                                            label: 'Last Name',
                                            controller: _lastNameController,
                                          ),
                                          const SizedBox(height: 16),

                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Department',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              DropdownButtonFormField<String>(
                                                initialValue:
                                                    _selectedDepartment,
                                                dropdownColor: Colors.grey[800],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                ),
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  fillColor: Colors.grey[800]!
                                                      .withValues(alpha: 0.5),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          25.0,
                                                        ),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 12.0,
                                                      ),
                                                ),
                                                hint: Text(
                                                  'Select Department',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                items: _departments.map((
                                                  String department,
                                                ) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: department,
                                                    child: Text(department),
                                                  );
                                                }).toList(),
                                                onChanged: (String? newValue) {
                                                  setState(() {
                                                    _selectedDepartment =
                                                        newValue;
                                                  });
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please select a department';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxWidth = constraints.maxWidth > 0
                                ? constraints.maxWidth.clamp(0.0, 590.0)
                                : 590.0;
                            return SizedBox(
                              width: maxWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Designation',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedDesignation,
                                    dropdownColor: Colors.grey[800],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey[800]!.withValues(
                                        alpha: 0.5,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          25.0,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 12.0,
                                          ),
                                    ),
                                    hint: Text(
                                      'Select Designation',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    items: _designations.map((
                                      String designation,
                                    ) {
                                      return DropdownMenuItem<String>(
                                        value: designation,
                                        child: Text(designation),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedDesignation = newValue;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please select a designation';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
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
                          final firstName = _firstNameController.text.trim();
                          final lastName = _lastNameController.text.trim();
                          final email = _emailController.text.trim();
                          final department = _selectedDepartment;
                          final designation = _selectedDesignation;

                          // Validate First Name
                          if (firstName.isEmpty) {
                            await _playErrorSound();
                            _showValidationError(
                              'First Name',
                              'Please enter your first name to continue with onboarding.',
                            );
                            return;
                          }

                          // Validate Last Name
                          if (lastName.isEmpty) {
                            await _playErrorSound();
                            _showValidationError(
                              'Last Name',
                              'Please enter your last name to continue with onboarding.',
                            );
                            return;
                          }

                          // Validate Email Address
                          if (email.isEmpty) {
                            await _playErrorSound();
                            _showValidationError(
                              'Email Address',
                              'Please enter your email address to continue with onboarding.',
                            );
                            return;
                          }

                          // Validate Email Domain
                          if (!email.toLowerCase().endsWith('@khonology.com')) {
                            await _playErrorSound();
                            final currentContext = context;
                            if (!currentContext.mounted) return;
                            showDialog(
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

                          // Validate Department
                          if (department == null || department.isEmpty) {
                            await _playErrorSound();
                            _showValidationError(
                              'Department',
                              'Please select your department to continue with onboarding.',
                            );
                            return;
                          }

                          // Validate Designation
                          if (designation == null || designation.isEmpty) {
                            await _playErrorSound();
                            _showValidationError(
                              'Designation',
                              'Please select your designation to continue with onboarding.',
                            );
                            return;
                          }

                          final authProvider = context.read<AuthProvider>();
                          final navigator = Navigator.of(context);
                          final success = await authProvider.login(
                            email,
                            firstName: _firstNameController.text,
                            lastName: _lastNameController.text,
                            department: _selectedDepartment ?? '',
                            designation: _selectedDesignation ?? '',
                            role: null,
                          );
                          if (!mounted) return;

                          if (success) {
                            if (authProvider.userAlreadyOnboarded) {
                              await _playErrorSound();
                              _showValidationError(
                                'Already Onboarded',
                                'You have already completed the onboarding process. You can proceed to the main application.',
                              );
                              await Future.delayed(const Duration(seconds: 2));
                            }
                            if (!mounted) return;
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) =>
                                    LobbyScreen(oauth: widget.oauth),
                              ),
                              (route) => false,
                            );
                          } else {
                            await _playErrorSound();
                            _showValidationError(
                              'Registration Failed',
                              'Registration/Login failed. Please try again.',
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
                        isBackButton: true,
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

  Widget _buildTextField({
    required String label,
    String? hint,
    String? hintText,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          decoration: InputDecoration(
            hintText: hintText ?? hint ?? _getHintText(label),
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[800]!.withValues(alpha: 0.5),
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
      ],
    );
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
        return Dialog(
          backgroundColor: Colors.transparent,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$fieldName Required',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: const TextStyle(
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
  }

  String _getHintText(String label) {
    switch (label) {
      case 'First Name':
        return 'John';
      case 'Last Name':
        return 'Doe';
      case 'Email Address':
        return 'john.doe@example.com';
      default:
        return '';
    }
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

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    bool isBackButton = false,
  }) {
    return _ClickBubblyButton(
      text: text,
      color: color,
      onPressed: onPressed,
      animationKey: isBackButton ? null : _animationKey,
      isBackButton: isBackButton,
    );
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
  bool _isAnimating = false;

  @override
  Widget build(BuildContext context) {
    return LoadingConfirmButton(
      text: widget.text,
      color: widget.color,
      onPressed: () async {
        SoundSystem.playButtonClick();
        if (_isAnimating) {
          return;
        }
        _isAnimating = true;
        if (widget.animationKey?.currentState != null && !_isAnimating) {
          // Guard to avoid double trigger if state changed mid-frame
          widget.animationKey!.currentState!.triggerParticleExplosion();
        }
        if (widget.animationKey?.currentState != null) {
          widget.animationKey!.currentState!.triggerParticleExplosion();
        }
        widget.onLoadingChanged(true);
        await widget.onPressed();
        if (mounted) {
          widget.onLoadingChanged(false);
        }
        _isAnimating = false;
      },
    );
  }
}

class _ClickBubblyButton extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
  final GlobalKey<FloatingCirclesParticleAnimationState>? animationKey;
  final bool isBackButton;
  const _ClickBubblyButton({
    required this.text,
    required this.color,
    required this.onPressed,
    this.animationKey,
    this.isBackButton = false,
  });

  @override
  State<_ClickBubblyButton> createState() => _ClickBubblyButtonState();
}

class _ClickBubblyButtonState extends State<_ClickBubblyButton>
    with TickerProviderStateMixin {
  late AnimationController _clickController;
  late AnimationController _backAnimationController;
  late AnimationController _dissolveController;
  Animation<double> _clickProgress = const AlwaysStoppedAnimation<double>(0.0);
  Animation<double> _fadeAnimation = const AlwaysStoppedAnimation<double>(1.0);
  Animation<double> _scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);
  Animation<double> _dissolveProgress = const AlwaysStoppedAnimation<double>(
    0.0,
  );
  List<DissolveParticleData> _dissolveParticles = [];
  bool _showDissolveParticles = false;

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
    _backAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _backAnimationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _backAnimationController, curve: Curves.easeOut),
    );
    _dissolveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _dissolveProgress = CurvedAnimation(
      parent: _dissolveController,
      curve: Curves.easeOut,
    );
  }

  void _triggerDissolve() {
    final buttonSize = const Size(250, 50);
    final center = Offset(buttonSize.width / 2, buttonSize.height / 2);
    _dissolveParticles = [];

    // Generate particles from the button surface
    for (int i = 0; i < 30; i++) {
      final angle = (i / 30) * 2 * math.pi + (math.Random().nextDouble() * 0.3);
      final speed = 60 + (math.Random().nextDouble() * 40);
      _dissolveParticles.add(
        DissolveParticleData(
          startPosition:
              center + Offset(math.cos(angle) * 20, math.sin(angle) * 20),
          angle: angle,
          speed: speed,
          size: 1.5 + (math.Random().nextDouble() * 2.5),
          opacity: 0.4 + (math.Random().nextDouble() * 0.3),
        ),
      );
    }

    setState(() {
      _showDissolveParticles = true;
    });
    _dissolveController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _showDissolveParticles = false;
          _dissolveParticles = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _clickController.dispose();
    _backAnimationController.dispose();
    _dissolveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC10D00);
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: widget.isBackButton
              ? Listenable.merge([
                  _backAnimationController,
                  _dissolveController,
                ])
              : _clickController,
          builder: (context, child) {
            return Opacity(
              opacity: widget.isBackButton && _dissolveProgress.value > 0.3
                  ? 1.0 - ((_dissolveProgress.value - 0.3) / 0.7)
                  : (widget.isBackButton ? _fadeAnimation.value : 1.0),
              child: Transform.scale(
                scale: widget.isBackButton && _dissolveProgress.value > 0.3
                    ? 1.0 - ((_dissolveProgress.value - 0.3) / 0.7) * 0.2
                    : (widget.isBackButton ? _scaleAnimation.value : 1.0),
                child: Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: MaterialButton(
            onPressed: () {
              SoundSystem.playButtonClick();
              if (widget.isBackButton) {
                _triggerDissolve();
                if (widget.animationKey?.currentState != null) {
                  widget.animationKey!.currentState!.triggerDissolve();
                }
                Future.delayed(
                  const Duration(milliseconds: 600),
                  widget.onPressed,
                );
              } else {
                _clickController.forward(from: 0);
                if (widget.animationKey?.currentState != null) {
                  widget.animationKey!.currentState!.triggerParticleExplosion();
                }
                Future.delayed(
                  const Duration(milliseconds: 1200),
                  widget.onPressed,
                );
              }
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
        if (!widget.isBackButton)
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
        if (widget.isBackButton && _showDissolveParticles)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _dissolveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DissolveParticlesPainter(
                      particles: _dissolveParticles,
                      progress: _dissolveProgress.value,
                      color: widget.color,
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

class DissolveParticleData {
  final Offset startPosition;
  final double angle;
  final double speed;
  final double size;
  final double opacity;

  DissolveParticleData({
    required this.startPosition,
    required this.angle,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

class _DissolveParticlesPainter extends CustomPainter {
  final List<DissolveParticleData> particles;
  final double progress;
  final Color color;

  _DissolveParticlesPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      final distance = particle.speed * progress;
      final x =
          center.dx +
          (particle.startPosition.dx - center.dx) +
          math.cos(particle.angle) * distance;
      final y =
          center.dy +
          (particle.startPosition.dy - center.dy) +
          math.sin(particle.angle) * distance;

      final currentOpacity = particle.opacity * (1.0 - progress);
      final currentSize = particle.size * (1.0 - progress * 0.5);

      paint.color = color.withValues(alpha: currentOpacity);
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DissolveParticlesPainter oldDelegate) {
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
