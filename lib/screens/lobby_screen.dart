import 'package:flutter/material.dart';
import 'auth_screen.dart'; // Import AuthScreen
import 'package:flutter_aad_oauth/flutter_aad_oauth.dart'; // Import FlutterAadOauth
import 'package:video_player/video_player.dart';

class LobbyScreen extends StatefulWidget {
  final FlutterAadOauth oauth; // Receive the oauth object
  const LobbyScreen({super.key, required this.oauth}); // Update constructor

  @override
  LobbyScreenState createState() => LobbyScreenState();
}

class LobbyScreenState extends State<LobbyScreen> {
  double _discsOpacity = 0.0; // Initial opacity for discs.png
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(
      'assets/images/animated_rocket.mp4',
    )
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _videoController.play();
          });
        }
      });
    // Trigger fade-in animation when the screen is initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _discsOpacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Set to transparent to show background image
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
            ), // Use the new background image
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rocket Asset
                  if (_videoController.value.isInitialized)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: ClipOval(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController.value.size.width,
                            height: _videoController.value.size.height,
                            child: VideoPlayer(_videoController),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 72),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 24), // Added spacing for the new button
                  Container(
                    width: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => AuthScreen(oauth: widget.oauth),
                          ),
                          (Route<dynamic> route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC10D00), // Button color
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
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
                  ),
                  const SizedBox(height: 32),
                  // Discs Asset
                  AnimatedOpacity(
                    opacity: _discsOpacity,
                    duration: const Duration(milliseconds: 1000),
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Image.asset(
                        'assets/videos/spinning_discs.gif', // Discs asset
                        height: 122, // Adjust height as needed
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
