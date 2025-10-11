import 'package:flutter/material.dart';
import 'auth_screen.dart'; // Import AuthScreen
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart'; // Import FlutterAadOauth

class LobbyScreen extends StatefulWidget {
  final FlutterAadOauth oauth; // Receive the oauth object
  const LobbyScreen({super.key, required this.oauth}); // Update constructor

  @override
  LobbyScreenState createState() => LobbyScreenState();
}

class LobbyScreenState extends State<LobbyScreen> {
  double _discsOpacity = 0.0; // Initial opacity for discs.png

  @override
  void initState() {
    super.initState();
    // Trigger fade-in animation when the screen is initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set to transparent to show background image
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png'), // Use the new background image
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rocket Asset
              Image.asset(
                'assets/images/rokects.png', // Rocket asset
                height: 120, // Adjusted height to make it larger
              ),
              const SizedBox(height: 32),
              // Khonology Asset
              Image.asset(
                'assets/images/khono.png', // Khonology asset
                height: 100, // Adjust height as needed
              ),
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
              const SizedBox(height: 32), // Added spacing for the new button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => AuthScreen(oauth: widget.oauth)),
                    (Route<dynamic> route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00), // Button color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins', // Apply Poppins font
                  ),
                ),
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
    );
  }
}
