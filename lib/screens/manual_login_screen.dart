// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../main.dart'; // Import MainScreen
import 'dart:async'; // Import Timer
import '../providers/auth_provider.dart'; // Import AuthProvider
import 'package:provider/provider.dart'; // Import Provider
import '../widgets/animations/loading_button.dart';

class ManualLoginScreen extends StatefulWidget {
  const ManualLoginScreen({super.key});

  @override
  ManualLoginScreenState createState() => ManualLoginScreenState();
}

class ManualLoginScreenState extends State<ManualLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  double _discsOpacity = 0.0; // Initial opacity for discs.png

  // List of hint texts
  /*
  final List<String> _hintTexts = const [
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
  int _currentHintIndex = 0;
  double _hintTextOpacity = 1.0;
  late Timer _timer;
  */

  @override
  void initState() {
    super.initState();
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
        _hintTextOpacity = 0.0; // Start fade-out
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _hintTexts.length;
          _hintTextOpacity = 1.0; // Start fade-in
        });
      });
    });
  }
  */

  @override
  void dispose() {
    _emailController.dispose();
    /*_timer.cancel();*/ // Cancel the timer to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Set to transparent to show background image
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
                  const SizedBox(
                    height: 48,
                  ), // Adjusted spacing after khono.png
                  // Removed 'KHONOLOGY' text
                  const SizedBox(height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Address',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                        decoration: InputDecoration(
                          hintText: 'example@khonology.com',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  LoadingConfirmButton(
                    text: 'CONFIRM',
                    color: const Color(0xFFC10D00),
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

                      final authProvider = context.read<AuthProvider>();
                      final success = await authProvider.manualLogin(
                        email,
                      );

                      if (!mounted) return;

                      if (success) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(
                              initialIndex: 6, // Navigate to User Management screen
                            ),
                          ),
                          (route) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Login failed. Please check your email address and try again.',
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

  Widget _buildButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return _ClickBubblyButton(
      text: text,
      color: color,
      onPressed: onPressed,
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
  Animation<double> _clickProgress =
      const AlwaysStoppedAnimation<double>(0.0);

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
              Future.delayed(const Duration(milliseconds: 200), widget.onPressed);
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
      canvas.drawCircle(Offset(x * size.width, y + size.height * 0.1), r, paint);
    }
    for (final x in bottomXs) {
      final p = progress;
      final y = size.height + size.height * (0.8 * p);
      final r = (size.height * 0.12) * (1.0 - p);
      paint.color = color.withValues(alpha: 0.5 * (1.0 - p));
      canvas.drawCircle(Offset(x * size.width, y - size.height * 0.1), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
