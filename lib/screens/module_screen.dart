import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
  void initState() {
    super.initState();
    // Fetch user module access and token when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        authProvider.fetchCurrentUserModuleAccess();
        // Fetch token if not already loaded
        if (authProvider.userToken == null) {
          authProvider.fetchUserToken();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {

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
                return Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final isAdmin =
                        authProvider.userRole?.toLowerCase() == 'admin';
                    final hasPDHAccess = authProvider.hasModuleAccess('PDH');
                    final hasSkillsHeatmapAccess = authProvider.hasModuleAccess(
                      'Skills Heatmap',
                    );
                    final hasRecruitmentAccess = authProvider.hasModuleAccess(
                      'Automated Recruitment Workflow',
                    ) || authProvider.hasModuleAccess('Recruitment');

                    // Admin users see all cards, Staff users see only cards they have access to
                    final showPDH = isAdmin || hasPDHAccess;
                    final showSkillsHeatmap = isAdmin || hasSkillsHeatmapAccess;
                    final showRecruitment = isAdmin || hasRecruitmentAccess;

                    // If no cards to show, show a message
                    if (!showPDH && !showSkillsHeatmap && !showRecruitment) {
                      return const Center(
                        child: Text(
                          'No module access assigned. Please contact your administrator.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final bool isMobile = constraints.maxWidth < 768;
                    final List<Widget> cards = [];

                    // Count how many cards will be shown
                    int cardCount = 0;
                    if (showPDH) cardCount++;
                    if (showSkillsHeatmap) cardCount++;
                    if (showRecruitment) cardCount++;
                    
                    // Calculate available width and card width based on number of cards
                    final double availableWidth = constraints.maxWidth - 32.0; // Account for padding
                    final double calculatedCardWidth = isMobile
                        ? (constraints.maxWidth > 500
                              ? 500
                              : constraints.maxWidth * 0.9)
                        : cardCount > 0
                            ? (availableWidth - (20.0 * (cardCount - 1))) / cardCount
                            : 300.0; // Default fallback width

                    if (showPDH) {
                      cards.add(
                        _buildModuleCard(
                          context: context,
                          cardWidth: calculatedCardWidth,
                          title: 'Personal Development Hub',
                          buttonText: 'Launch',
                          url: 'https://pdhproject.netlify.app/',
                        ),
                      );
                    }

                    if (showSkillsHeatmap) {
                      if (cards.isNotEmpty && isMobile) {
                        cards.add(const SizedBox(height: 20.0));
                      } else if (cards.isNotEmpty && !isMobile) {
                        cards.add(const SizedBox(width: 20.0));
                      }

                      cards.add(
                        _buildModuleCard(
                          context: context,
                          cardWidth: calculatedCardWidth,
                          title: 'Resource Capacity & Skills Heatmap',
                          buttonText: 'Launch',
                          url: 'https://resource-capacity.netlify.app/',
                        ),
                      );
                    }

                    if (showRecruitment) {
                      if (cards.isNotEmpty && isMobile) {
                        cards.add(const SizedBox(height: 20.0));
                      } else if (cards.isNotEmpty && !isMobile) {
                        cards.add(const SizedBox(width: 20.0));
                      }

                      cards.add(
                        _buildModuleCard(
                          context: context,
                          cardWidth: calculatedCardWidth,
                          title: 'Automated Recruitment Workflow',
                          buttonText: 'Launch',
                          url: 'https://chimerical-quokka-d580e5.netlify.app/',
                        ),
                      );
                    }

                    if (isMobile) {
                      // Stack vertically on mobile
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: cards,
                      );
                    } else {
                      // Side by side on larger screens
                      return IntrinsicHeight(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: cards
                              .map((card) => Flexible(child: card))
                              .toList(),
                        ),
                      );
                    }
                  },
                );
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: cardWidth > 300 ? 26.0 : cardWidth > 200 ? 22.0 : 18.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 12.0),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w600,
                        color: primaryAccent,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 32.0),
                  _buildLaunchButton(text: buttonText, url: url),
                ],
              ),
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
    try {
      // Ensure URL uses HTTPS for secure transmission
      String secureUrl = url;
      if (secureUrl.startsWith('http://')) {
        secureUrl = secureUrl.replaceFirst('http://', 'https://');
      } else if (!secureUrl.startsWith('https://')) {
        secureUrl = 'https://$secureUrl';
      }

      // Check if this is a PDH URL (only PDH should get the token)
      final bool isPDHUrl = secureUrl.contains('pdhproject.netlify.app') ||
          secureUrl.contains('pdh');

      // Get user token from AuthProvider only if it's a PDH URL
      String? token;
      if (isPDHUrl) {
        final authProvider = context.read<AuthProvider>();
        token = authProvider.userToken;

        // If token is not available, try to fetch it
        if (token == null && authProvider.userEmail != null) {
          await authProvider.fetchUserToken();
          token = authProvider.userToken;
        }
      }

      // Append token as query parameter only for PDH URLs
      Uri uri = Uri.parse(secureUrl);
      if (isPDHUrl && token != null && token.isNotEmpty) {
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'token': token,
        });
      }

      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open link',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error opening link: ${e.toString()}',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
        ),
      );
    }
  }
}
