// ignore_for_file: use_build_context_synchronously, dead_code

import 'package:flutter/material.dart';
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart'; // Import for AAD OAuth
import 'package:provider/provider.dart'; // Import for AuthProvider
import '../providers/auth_provider.dart'; // Import AuthProvider
import 'lobby_screen.dart'; // Import LobbyScreen
import 'dart:async'; // Import Timer
import '../widgets/animations/loading_button.dart';

class OnboardingScreen extends StatefulWidget {
  final FlutterAadOauth oauth; // Receive the oauth object
  const OnboardingScreen({
    super.key,
    required this.oauth,
  }); // Update constructor

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  // Removed _departmentController as it will be managed by DropdownButtonFormField
  // Removed _designationController as it will be managed by DropdownButtonFormField
  double _discsOpacity = 0.0; // Initial opacity for discs.png

  final List<String> _departments = const [
    'Management',
    'Operations',
    'Finance',
    'HR',
    'Sales',
  ];
  String? _selectedDepartment; // New state variable for selected department

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
  String? _selectedDesignation; // New state variable for selected designation

  // List of hint texts
  /*
  final List<String> _emailHintTexts = const [
    'Nkosinathi.Radebe@Khonology.com',
    'Yannie.Nkuna@Khonology.com',
    'Mampopi.Tau@Khonology.com',
    'Dzunisani.Mabunda@Khonology.com',
    'Okuhle.Galdla@Khonology.com',
    'Kgothatso.Mokgashi@Khonology.com',
    'Thabang.Nkabinde@Khonology.com',
    'Thembelihle.Zulu@Khonology.com',
    'Sipho.Masango@Khonology.com',
    'Dapo.Adeyemo@Khonology.com',
    'Qiniso.Ngobese@Khonology.com',
    'Tiyane.Mahange@Khonology.com',
    'Tshiamo.Modubu@khonology.com',
  ];

  late final List<String> _firstNameHintTexts;
  late final List<String> _lastNameHintTexts;

  int _currentHintIndex = 0;
  late Timer _timer;
  */

  @override
  void initState() {
    super.initState();
    /*
    _firstNameHintTexts = _emailHintTexts.map((email) => email.split('.')[0]).toList();
    _lastNameHintTexts = _emailHintTexts.map((email) => email.split('.')[1].split('@')[0]).toList();
    */

    // Trigger fade-in animation when the screen is initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });
    /*_startHintTextAnimation();*/
  }

  /*
  void _startHintTextAnimation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _currentHintIndex = (_currentHintIndex + 1) % _emailHintTexts.length;
      });
    });
  }
  */

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    // Removed _departmentController.dispose();
    // Removed _designationController.dispose();
    /*_timer.cancel();*/ // Cancel the timer to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Dark background
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
                  // Khonology Asset
                  Image.asset(
                    'assets/images/khono.png', // Khonology asset
                    height: 100, // Adjust height as needed
                  ),
                  const SizedBox(height: 48),
                  // Text fields
                  Center(
                    child: SizedBox(
                      width:
                          590, // Reduced to fit within available space (287 + 16 + 287 = 590)
                      child: Row(
                        children: [
                          SizedBox(
                            width: 287, // Reduced to fit within constraints
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
                          SizedBox(
                            width: 287, // Reduced to fit within constraints
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  label: 'Surname',
                                  controller: _lastNameController,
                                ),
                                const SizedBox(height: 16),
                                // Department dropdown
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Replaced _buildTextField for Designation with DropdownButtonFormField
                  Center(
                    child: SizedBox(
                      width: 590, // Full width matching the two columns above
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
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Buttons
                  LoadingConfirmButton(
                    text: 'CONFIRM',
                    color: const Color(0xFFC10D00),
                    onPressed: () async {
                      final success = await context.read<AuthProvider>().login(
                        _emailController.text,
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
                      ).pop(); // Go back to the previous screen
                    },
                  ),
                  const SizedBox(height: 48),
                  // Discs Asset
                  AnimatedOpacity(
                    opacity: _discsOpacity,
                    duration: const Duration(milliseconds: 1000),
                    child: Image.asset(
                      'assets/images/discs.png', // Discs asset
                      height: 80, // Adjust height as needed
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
    // Explicitly define return type as String
    switch (label) {
      case 'First Name':
        return 'John'; // Static hint text
      case 'Surname':
        return 'Doe'; // Static hint text
      case 'Email Address':
        return 'john.doe@example.com'; // Static hint text
      default:
        return '';
    }
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return _ClickBubblyButton(text: text, color: color, onPressed: onPressed);
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
