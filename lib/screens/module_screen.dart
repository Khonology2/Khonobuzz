import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:url_launcher/url_launcher.dart';

// Define the custom colors used in the HTML design
const Color primaryDark = Color(0xFF1F2937);
const Color primaryAccent = Color(0xFFC10D00);

class ModuleScreen extends StatelessWidget {
  const ModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine the max width for the card content to match the HTML's max-w-xl
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth > 500 ? 500 : screenWidth * 0.9;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0), // rounded-2xl
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: Container
                (
                  width: cardWidth,
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: primaryDark.withOpacity(0.80), // translucent card
                    borderRadius: BorderRadius.circular(16.0), // rounded-2xl
                    border: Border.all(color: Colors.white24), // subtle border
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 25,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title: Welcome to Your Growth Engine
                      const Text(
                        'Welcome to Your Growth Engine',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32.0, // text-3xl/4xl
                          fontWeight: FontWeight.w900, // font-extrabold
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // Subtitle: Personal Development Hub
                      const Text(
                        'Personal Development Hub',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20.0, // text-xl
                          fontWeight: FontWeight.w600, // font-semibold
                          color: primaryAccent,
                        ),
                      ),
                      const SizedBox(height: 40.0), // mb-10

                      // Call to Action Button
                      _buildLaunchButton(context),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper function to build the main launch button
  Widget _buildLaunchButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _launchHub(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAccent, // bg-primary-accent
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // rounded-xl
        ),
        textStyle: const TextStyle(
          fontSize: 18.0, // text-lg
          fontWeight: FontWeight.bold, // font-bold
        ),
        elevation: 10, // shadow-lg
        shadowColor: primaryAccent.withOpacity(0.5), // shadow-[#C10D00]/50
      ),
      child: const Text('Launch Development Hub'),
    );
  }

  Future<void> _launchHub(BuildContext context) async {
    final Uri uri = Uri.parse('https://personal-developement-hub.netlify.app/');
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}
