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
                    final hasRecruitmentAccess =
                        authProvider.hasModuleAccess(
                          'Automated Recruitment Workflow',
                        ) ||
                        authProvider.hasModuleAccess('Recruitment');

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
                    // Reduced by 10% to match 90% zoom level
                    final double availableWidth =
                        constraints.maxWidth - 32.0; // Account for padding
                    final double calculatedCardWidth =
                        (isMobile
                            ? (constraints.maxWidth > 500
                                  ? 500
                                  : constraints.maxWidth * 0.9)
                            : cardCount > 0
                            ? (availableWidth - (18.0 * (cardCount - 1))) /
                                  cardCount // 20.0 * 0.9 = 18.0
                            : 300.0) *
                        0.9; // Apply 90% scale factor

                    if (showPDH) {
                      cards.add(
                        _buildModuleCard(
                          context: context,
                          cardWidth: calculatedCardWidth,
                          titleLines: ['Personal', 'Development', 'Hub'],
                          buttonText: 'Launch',
                          url: 'https://pdh-web-app.onrender.com',
                        ),
                      );
                    }

                    if (showSkillsHeatmap) {
                      if (cards.isNotEmpty && isMobile) {
                        cards.add(const SizedBox(height: 18.0)); // 20.0 * 0.9
                      } else if (cards.isNotEmpty && !isMobile) {
                        cards.add(const SizedBox(width: 18.0)); // 20.0 * 0.9
                      }

                      cards.add(
                        _buildModuleCard(
                          context: context,
                          cardWidth: calculatedCardWidth,
                          titleLines: ['Resource Capacity', '&', 'Heatmap'],
                          buttonText: 'Launch',
                          url: 'https://resource-capacity.netlify.app/',
                        ),
                      );
                    }

                    if (showRecruitment) {
                      if (cards.isNotEmpty && isMobile) {
                        cards.add(const SizedBox(height: 18.0)); // 20.0 * 0.9
                      } else if (cards.isNotEmpty && !isMobile) {
                        cards.add(const SizedBox(width: 18.0)); // 20.0 * 0.9
                      }

                      cards.add(
                        _buildModuleCard(
                          context: context,
                          cardWidth: calculatedCardWidth,
                          titleLines: ['Automated', 'Recruitment', 'Workflow'],
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
    required List<String> titleLines,
    String? subtitle,
    required String buttonText,
    required String url,
  }) {
    return _HoverableModuleCard(
      context: context,
      cardWidth: cardWidth,
      titleLines: titleLines,
      subtitle: subtitle,
      buttonText: buttonText,
      url: url,
    );
  }
}

class _HoverableModuleCard extends StatefulWidget {
  final BuildContext context;
  final double cardWidth;
  final List<String> titleLines;
  final String? subtitle;
  final String buttonText;
  final String url;

  const _HoverableModuleCard({
    required this.context,
    required this.cardWidth,
    required this.titleLines,
    this.subtitle,
    required this.buttonText,
    required this.url,
  });

  @override
  State<_HoverableModuleCard> createState() => _HoverableModuleCardState();
}

class _HoverableModuleCardState extends State<_HoverableModuleCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _animationController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.cardWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.cardWidth,
                padding: const EdgeInsets.all(28.8), // 32.0 * 0.9
                decoration: BoxDecoration(
                  color: primaryDark.withValues(alpha: _isHovered ? 0.7 : 0.5),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: _isHovered ? Colors.white38 : Colors.white24,
                    width: _isHovered ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? Colors.black.withValues(alpha: 0.7)
                          : Colors.black54,
                      blurRadius: _isHovered ? 35 : 25,
                      offset: Offset(0, _isHovered ? 15 : 10),
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.titleLines.map((line) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 3.6,
                            ), // 4.0 * 0.9
                            child: Text(
                              line,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: widget.cardWidth > 300
                                    ? 23.4 // 26.0 * 0.9
                                    : widget.cardWidth > 200
                                    ? 19.8 // 22.0 * 0.9
                                    : 16.2, // 18.0 * 0.9
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (widget.subtitle != null &&
                          widget.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 10.8), // 12.0 * 0.9
                        Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18.0, // 20.0 * 0.9
                            fontWeight: FontWeight.w600,
                            color: primaryAccent,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 28.8), // 32.0 * 0.9
                      ElevatedButton(
                        onPressed: () =>
                            _launchUrlFromContext(widget.context, widget.url),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36.0, // 40.0 * 0.9
                            vertical: 14.4, // 16.0 * 0.9
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              45.0,
                            ), // 50.0 * 0.9
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16.2, // 18.0 * 0.9
                            fontWeight: FontWeight.bold,
                          ),
                          elevation: 10,
                          shadowColor: primaryAccent.withValues(alpha: 0.5),
                        ),
                        child: Text(widget.buttonText),
                      ),
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

  // ignore: unused_element
  Widget _buildLaunchButton({
    required BuildContext context,
    required String text,
    required String url,
  }) {
    return ElevatedButton(
      onPressed: () => _launchUrl(context, url),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50.0),
        ),
        textStyle: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        elevation: 10,
        shadowColor: primaryAccent.withValues(alpha: 0.5),
      ),
      child: Text(text),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    await _launchUrlFromContext(context, url);
  }
}

// Standalone function to launch URLs - can be called from anywhere
Future<void> _launchUrlFromContext(BuildContext context, String url) async {
  try {
    // Ensure URL uses HTTPS for secure transmission
    String secureUrl = url;
    if (secureUrl.startsWith('http://')) {
      secureUrl = secureUrl.replaceFirst('http://', 'https://');
    } else if (!secureUrl.startsWith('https://')) {
      secureUrl = 'https://$secureUrl';
    }

    // Check if this is a PDH URL (only PDH should get the token)
    final bool isPDHUrl =
        secureUrl.contains('pdh-web-app.onrender.com') ||
        secureUrl.contains('pdh');

    // Get user token from AuthProvider only if it's a PDH URL
    String? token;
    if (isPDHUrl) {
      final authProvider = context.read<AuthProvider>();

      // ALWAYS generate a fresh token when launching PDH
      // This ensures the token is never expired
      if (authProvider.userEmail != null) {
        // Generate fresh token before launching
        await authProvider.fetchUserToken();
        token = authProvider.userToken;

        if (token == null || token.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to generate authentication token. Please try again.',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          );
          return;
        }
      }
    }

    // Build redirect URL with token for PDH URLs
    Uri uri = Uri.parse(secureUrl);
    if (isPDHUrl && token != null && token.isNotEmpty) {
      // Format: https://pdh-app-url/?token=<fresh-jwt>
      uri = uri.replace(queryParameters: {'token': token});
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!context.mounted) return;
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
    if (!context.mounted) return;
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
