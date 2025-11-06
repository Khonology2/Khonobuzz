import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:url_launcher/url_launcher.dart';

// Define the custom colors used in the HTML design
const Color primaryDark = Color(0xFF1F2937);
const Color primaryAccent = Color(0xFFC10D00);

class ModuleScreen extends StatefulWidget {
  const ModuleScreen({super.key});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  @override
  Widget build(BuildContext context) {
    // Determine the max width for the card content to match the HTML's max-w-xl
    final double screenWidth = MediaQuery.of(context).size.width;
    final double availableWidth = screenWidth - 32.0; // Account for padding
    final double cardWidth =
        (availableWidth / 2) - 10.0; // Split in half with spacing

    return Scaffold(
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
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 768;
                if (isMobile) {
                  // Stack vertically on mobile
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModuleCard(
                        context: context,
                        cardWidth: constraints.maxWidth > 500
                            ? 500
                            : constraints.maxWidth * 0.9,
                        title: 'Resource and Capacity',
                        subtitle: 'Resource Capacity & Skills Heatmap',
                        buttonText: 'Launch Development Hub',
                        url: 'https://personal-developement-hub.netlify.app/',
                      ),
                      const SizedBox(height: 20.0),
                      _buildModuleCard(
                        context: context,
                        cardWidth: constraints.maxWidth > 500
                            ? 500
                            : constraints.maxWidth * 0.9,
                        title: 'Welcome to Your Growth Engine',
                        subtitle: 'Personal Development Hub',
                        buttonText: 'Launch Heatmap',
                        url: 'https://resource-capacity.netlify.app/',
                      ),
                    ],
                  );
                } else {
                  // Side by side on larger screens
                  return IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: _buildModuleCard(
                            context: context,
                            cardWidth: cardWidth,
                            title: 'Personal Development Hub (PDH)',
                            buttonText: 'Launch Development Hub',
                            url:
                                'https://personal-developement-hub.netlify.app/',
                          ),
                        ),
                        const SizedBox(width: 20.0),
                        Flexible(
                          child: _buildModuleCard(
                            context: context,
                            cardWidth: cardWidth,
                            title: 'Resource Capacity & Skills Heatmap',
                            buttonText: 'Launch Heatmap',
                            url: 'https://resource-capacity.netlify.app/',
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required double cardWidth,
    required String title,
    String? subtitle,
    required String buttonText,
    required String url,
  }) {
    return SizedBox(
      width: cardWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            width: cardWidth,
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: primaryDark.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: Colors.white24),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w600,
                      color: primaryAccent,
                    ),
                  ),
                ],
                const SizedBox(height: 40.0),
                _buildLaunchButton(text: buttonText, url: url),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaunchButton({required String text, required String url}) {
    return ElevatedButton(
      onPressed: () => _launchUrl(url),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        textStyle: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        elevation: 10,
        shadowColor: primaryAccent.withValues(alpha: 0.5),
      ),
      child: Text(text),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }
}
