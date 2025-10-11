import 'package:flutter/material.dart';
import 'package:khonology_app/main.dart'; // Import MainScreen
import 'dart:async'; // Import Timer

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
                      const SizedBox(height: 8),
                      /*AnimatedOpacity(
                        opacity: 1.0, // Always visible
                        duration: const Duration(milliseconds: 500),
                        child: const Text(
                          'Enter Khonology Specific Email Address.',
                          style: TextStyle(
                            color: Color(0xFFC10D00),
                            fontSize: 12,
                          ),
                        ),
                      ),*/
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildButton(
                    text: 'CONFIRM',
                    color: const Color(0xFFC10D00),
                    onPressed: () {
                      // Implement confirm logic here
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const MainScreen(),
                        ),
                        (route) => false,
                      );
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
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50.0),
      ),
      child: MaterialButton(
        onPressed: onPressed,
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
}
