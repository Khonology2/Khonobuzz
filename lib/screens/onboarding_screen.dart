

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'lobby_screen.dart';
import 'dart:async';
import '../widgets/animations/loading_button.dart';

class OnboardingScreen extends StatefulWidget {
  final FlutterAadOauth? oauth;
  const OnboardingScreen({
    super.key,
    this.oauth,
  });

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
  late AnimationController
  _blinkController;
  late Animation<double> _blinkAnimation;

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


    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 500,
      ),
    );

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeInOut,
      ),
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


    super.dispose();
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
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  Image.asset(
                    'assets/images/khono.png',
                    height: 100,
                  ),
                  const SizedBox(height: 48),

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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildTextField(
                                        label: 'Surname',
                                        controller: _lastNameController,
                                      ),
                                      const SizedBox(height: 16),

                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
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
                                            initialValue: _selectedDepartment,
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
                                              'Select Department',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            items: _departments.map((
                                              String department,
                                            ) {
                                              return DropdownMenuItem<String>(
                                                value: department,
                                                child: Text(department),
                                              );
                                            }).toList(),
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                _selectedDepartment = newValue;
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildTextField(
                                          label: 'Surname',
                                          controller: _lastNameController,
                                        ),
                                        const SizedBox(height: 16),

                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                              initialValue: _selectedDepartment,
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
                                                'Select Department',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              items: _departments.map((
                                                String department,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: department,
                                                  child: Text(department),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                setState(() {
                                                  _selectedDepartment = newValue;
                                                });
                                              },
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
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
                                  borderRadius: BorderRadius.circular(25.0),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
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
                              items: _designations.map((String designation) {
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
                            content: Text('Please enter your email address.'),
                          ),
                        );
                        return;
                      }


                      if (!email.toLowerCase().endsWith('@khonology.com')) {

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
                        return;
                      }

                      final success = await context.read<AuthProvider>().login(
                        email,
                        firstName: _firstNameController.text,
                        lastName: _lastNameController.text,
                        department: _selectedDepartment ?? '',
                        designation: _selectedDesignation ?? '',
                        role: null,
                      );
                      if (!mounted) return;

                      if (success) {
                        if (context.read<AuthProvider>().userAlreadyOnboarded) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You have already onboarded!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          await Future.delayed(const Duration(seconds: 2));
                        }
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) =>
                                LobbyScreen(oauth: widget.oauth),
                          ),
                          (route) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Registration/Login failed. Please try again.',
                            ),
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
                      Navigator.of(
                        context,
                      ).pop();
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

  String _getHintText(String label) {

    switch (label) {
      case 'First Name':
        return 'John';
      case 'Surname':
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
  }) {
    return _ClickBubblyButton(text: text, color: color, onPressed: onPressed);
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
              _clickController.forward(from: 0);
              Future.delayed(
                const Duration(milliseconds: 200),
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
