import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

// Define the custom colors used in the HTML design
const Color primaryDark = Color(0xFF1F2937);
const Color primaryAccent = Color(0xFFC10D00);

class ModuleScreen extends StatefulWidget {
  const ModuleScreen({super.key});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  bool _isLoadingModuleAccess = false;

  @override
  void initState() {
    super.initState();
    // Fetch immediately when screen loads - don't wait for postFrameCallback
    _loadModuleAccess();
  }

  Future<void> _loadModuleAccess() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    // If module access is already loaded, we're done
    if (authProvider.userModuleAccess != null &&
        authProvider.userModuleAccess!.isNotEmpty) {
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        _isLoadingModuleAccess = true;
      });
    }

    // First, try to get from UserProvider cache (much faster than API call)
    String? cachedModuleAccess;
    if (userProvider.users.isNotEmpty && authProvider.userEmail != null) {
      try {
        final currentUser = userProvider.users.firstWhere(
          (u) => u.email.toLowerCase() == authProvider.userEmail!.toLowerCase(),
        );
        cachedModuleAccess = currentUser.moduleAccess;
        if (cachedModuleAccess != null && cachedModuleAccess.isNotEmpty) {
          // Set it directly in AuthProvider
          authProvider.setModuleAccess(cachedModuleAccess);
          debugPrint(
            '[ModuleScreen] Module access loaded from UserProvider cache',
          );
        }
      } catch (_) {
        // User not found in cache, will fetch from API
      }
    }

    // If not found in cache, fetch from API
    if (cachedModuleAccess == null || cachedModuleAccess.isEmpty) {
      await authProvider.fetchCurrentUserModuleAccess(
        preFetchedModuleAccess: cachedModuleAccess,
      );
    }

    // Also fetch token if needed (non-blocking)
    if (authProvider.userToken == null) {
      authProvider.fetchUserToken();
    }

    if (mounted) {
      setState(() {
        _isLoadingModuleAccess = false;
      });
    }
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
          child: Transform.scale(
            scale: 0.8,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      // Show loading indicator while fetching module access
                      if (_isLoadingModuleAccess &&
                          authProvider.userModuleAccess == null) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryAccent,
                            ),
                          ),
                        );
                      }

                      final isAdmin =
                          authProvider.userRole?.toLowerCase() == 'admin';
                      final hasPDHAccess = authProvider.hasModuleAccess('PDH');
                      final hasSkillsHeatmapAccess = authProvider
                          .hasModuleAccess('Skills Heatmap');
                      final hasRecruitmentAccess =
                          authProvider.hasModuleAccess(
                            'Automated Recruitment Workflow',
                          ) ||
                          authProvider.hasModuleAccess('Recruitment');

                      // Admin users see all cards, Staff users see only cards they have access to
                      final showPDH = isAdmin || hasPDHAccess;
                      final showSkillsHeatmap =
                          isAdmin || hasSkillsHeatmapAccess;
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

                      final List<Widget> cards = [];

                      // Calculate card width - use a fixed max width or responsive width
                      final double calculatedCardWidth =
                          (constraints.maxWidth > 500
                              ? 500
                              : constraints.maxWidth * 0.9) *
                          0.9; // Apply 90% scale factor

                      if (showPDH) {
                        cards.add(
                          _buildModuleCard(
                            context: context,
                            cardWidth: calculatedCardWidth,
                            titleLines: ['Personal', 'Development', 'Hub'],
                            buttonText: 'Launch',
                            url: 'https://pdh-web-app.onrender.com',
                            moduleKey: 'pdh',
                          ),
                        );
                      }

                      if (showSkillsHeatmap) {
                        if (cards.isNotEmpty) {
                          cards.add(const SizedBox(height: 18.0)); // 20.0 * 0.9
                        }

                        cards.add(
                          _buildModuleCard(
                            context: context,
                            cardWidth: calculatedCardWidth,
                            titleLines: [
                              'Resource',
                              'Capacity &',
                              'Skills heatmap',
                            ],
                            buttonText: 'Launch',
                            url: 'https://resource-capacity.netlify.app/',
                            moduleKey: 'skills_heatmap',
                          ),
                        );
                      }

                      if (showRecruitment) {
                        if (cards.isNotEmpty) {
                          cards.add(const SizedBox(height: 18.0)); // 20.0 * 0.9
                        }

                        cards.add(
                          _buildModuleCard(
                            context: context,
                            cardWidth: calculatedCardWidth,
                            titleLines: [
                              'Automated',
                              'Recruitment',
                              'Workflow',
                            ],
                            buttonText: 'Launch',
                            url:
                                'https://willowy-scone-c14f7c.netlify.app/',
                            moduleKey: 'recruitment',
                          ),
                        );
                      }

                      // Always stack vertically from top to bottom
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: cards,
                      );
                    },
                  );
                },
              ),
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
    required String moduleKey,
  }) {
    return _HoverableModuleCard(
      context: context,
      cardWidth: cardWidth,
      titleLines: titleLines,
      subtitle: subtitle,
      buttonText: buttonText,
      url: url,
      moduleKey: moduleKey,
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
  final String moduleKey;

  const _HoverableModuleCard({
    required this.context,
    required this.cardWidth,
    required this.titleLines,
    this.subtitle,
    required this.buttonText,
    required this.url,
    required this.moduleKey,
  });

  @override
  State<_HoverableModuleCard> createState() => _HoverableModuleCardState();
}

class _HoverableModuleCardState extends State<_HoverableModuleCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isLoading = false;
  String? _lastAccessedText;
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
    _loadLastAccessed();
  }

  Future<void> _loadLastAccessed() async {
    final lastAccessed = await _getLastAccessedTime(widget.moduleKey);
    if (mounted) {
      setState(() {
        _lastAccessedText = lastAccessed;
      });
    }
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
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: widget.cardWidth,
                    padding: const EdgeInsets.all(28.8), // 32.0 * 0.9
                    decoration: BoxDecoration(
                      color: primaryDark.withValues(
                        alpha: _isHovered ? 0.7 : 0.5,
                      ),
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
                          if (_lastAccessedText != null) ...[
                            const SizedBox(height: 10.8), // 12.0 * 0.9
                            Text(
                              _lastAccessedText!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.6, // 14.0 * 0.9
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28.8), // 32.0 * 0.9
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);
                                    try {
                                      await _launchUrlFromContext(
                                        widget.context,
                                        widget.url,
                                        widget.moduleKey,
                                      );
                                      // Reload last accessed time after launch
                                      await _loadLastAccessed();
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                      }
                                    }
                                  },
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
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                    ),
                                  )
                                : Text(widget.buttonText),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Center(child: _BouncingRedSpinner()),
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
    // This method is unused but kept for potential future use
    // If used, moduleKey should be provided
    await _launchUrlFromContext(context, url, 'unknown');
  }
}

// Bouncing red spinner widget
class _BouncingRedSpinner extends StatefulWidget {
  @override
  State<_BouncingRedSpinner> createState() => _BouncingRedSpinnerState();
}

class _BouncingRedSpinnerState extends State<_BouncingRedSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat();
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_bounceAnimation.value * 0.4),
          child: CircularProgressIndicator(
            strokeWidth: 4.0,
            valueColor: const AlwaysStoppedAnimation<Color>(primaryAccent),
          ),
        );
      },
    );
  }
}

// Helper functions for last accessed timestamp
Future<void> _saveLastAccessedTime(String moduleKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('last_accessed_$moduleKey', now);
  } catch (e) {
    debugPrint('Error saving last accessed time: $e');
  }
}

Future<String?> _getLastAccessedTime(String moduleKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_accessed_$moduleKey');
    if (timestamp == null) return null;

    final lastAccessed = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(lastAccessed);

    if (difference.inDays > 7) {
      // Show date if older than 7 days
      return 'Last accessed: ${DateFormat('MMM d, yyyy').format(lastAccessed)}';
    } else if (difference.inDays > 0) {
      // Show days ago
      final days = difference.inDays;
      return 'Last accessed: $days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      // Show hours ago
      final hours = difference.inHours;
      return 'Last accessed: $hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      // Show minutes ago
      final minutes = difference.inMinutes;
      return 'Last accessed: $minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      // Show just now
      return 'Last accessed: Just now';
    }
  } catch (e) {
    debugPrint('Error getting last accessed time: $e');
    return null;
  }
}

// Standalone function to launch URLs - can be called from anywhere
Future<void> _launchUrlFromContext(
  BuildContext context,
  String url,
  String moduleKey,
) async {
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

      // Use existing token if available, only fetch if null
      if (authProvider.userEmail != null) {
        token = authProvider.userToken;

        // Only fetch new token if current one is missing
        if (token == null || token.isEmpty) {
          // Show loading indicator while fetching token
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Generating authentication token...',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }

          // Fetch fresh token only if needed
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
    if (launched) {
      // Save last accessed time when successfully launched
      await _saveLastAccessedTime(moduleKey);
    } else {
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
