import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

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

    _loadModuleAccess();
  }

  Future<void> _loadModuleAccess() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    if (authProvider.userModuleAccess != null &&
        authProvider.userModuleAccess!.isNotEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingModuleAccess = true;
      });
    }

    String? cachedModuleAccess;
    if (userProvider.users.isNotEmpty && authProvider.userEmail != null) {
      try {
        final currentUser = userProvider.users.firstWhere(
          (u) => u.email.toLowerCase() == authProvider.userEmail!.toLowerCase(),
          orElse: () => throw StateError('Current user not found'),
        );

        cachedModuleAccess = currentUser.moduleAccess;
        if (cachedModuleAccess == null || cachedModuleAccess.isEmpty) {
          final moduleAccessRole = currentUser.moduleAccessRole;
          if (moduleAccessRole != null && moduleAccessRole.isNotEmpty) {
            final parts = moduleAccessRole.split(',');
            final List<String> moduleNames = [];
            for (var part in parts) {
              final trimmed = part.trim();
              if (trimmed.startsWith('PDH')) {
                if (!moduleNames.contains('Personal Development Hub')) {
                  moduleNames.add('Personal Development Hub');
                }
              } else if (trimmed.startsWith('Skills Heatmap')) {
                if (!moduleNames.contains(
                  'Resource & Capacity Skills Heatmap',
                )) {
                  moduleNames.add('Resource & Capacity Skills Heatmap');
                }
              } else if (trimmed.startsWith('Automated Recruitment Workflow')) {
                if (!moduleNames.contains('Automated Recruitment Workflow')) {
                  moduleNames.add('Automated Recruitment Workflow');
                }
              } else if (trimmed.startsWith('Proposal & SOW Builder') ||
                  trimmed.startsWith('SOW Builder')) {
                if (!moduleNames.contains('Proposal & SOW Builder')) {
                  moduleNames.add('Proposal & SOW Builder');
                }
              }
            }
            cachedModuleAccess = moduleNames.isEmpty
                ? null
                : moduleNames.join(',');
          }
        }
        if (cachedModuleAccess != null && cachedModuleAccess.isNotEmpty) {
          authProvider.setModuleAccess(cachedModuleAccess);
          debugPrint(
            '[ModuleScreen] Module access loaded from UserProvider cache',
          );
        }
      } catch (_) {}
    }

    if (cachedModuleAccess == null || cachedModuleAccess.isEmpty) {
      await authProvider.fetchCurrentUserModuleAccess(
        preFetchedModuleAccess: cachedModuleAccess,
      );
    }

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
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll<Color>(Colors.white),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Center(
                    child: Transform.scale(
                      scale: 0.8,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final authProvider =
                                context.watch<AuthProvider>();

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
                                authProvider.userRole?.toLowerCase() ==
                                    'admin';
                            final hasPDHAccess =
                                authProvider.hasModuleAccess('PDH') ||
                                authProvider.hasModuleAccess(
                                  'Personal Development Hub',
                                );
                            final hasSkillsHeatmapAccess =
                                authProvider.hasModuleAccess('Skills Heatmap') ||
                                authProvider.hasModuleAccess(
                                  'Resource & Capacity Skills Heatmap',
                                );
                            final hasRecruitmentAccess =
                                authProvider.hasModuleAccess(
                                      'Automated Recruitment Workflow',
                                    ) ||
                                    authProvider.hasModuleAccess(
                                      'Recruitment',
                                    );
                            final hasSOWBuilderAccess =
                                authProvider.hasModuleAccess(
                                      'Proposal & SOW Builder',
                                    ) ||
                                    authProvider.hasModuleAccess(
                                      'SOW Builder',
                                    );

                            final showPDH = isAdmin || hasPDHAccess;
                            final showSkillsHeatmap =
                                isAdmin || hasSkillsHeatmapAccess;
                            final showRecruitment =
                                isAdmin || hasRecruitmentAccess;
                            final showSOWBuilder =
                                isAdmin || hasSOWBuilderAccess;

                            if (!showPDH &&
                                !showSkillsHeatmap &&
                                !showRecruitment &&
                                !showSOWBuilder) {
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

                            final double availableWidth =
                                constraints.maxWidth - 32;
                            final double calculatedCardWidth =
                                ((availableWidth - 36) / (3 * 1.1)).clamp(
                              140.0,
                              400.0,
                            );

                            final List<Widget> topRow = [];
                            if (showPDH) {
                              topRow.add(
                                _buildModuleCard(
                                  context: context,
                                  cardWidth: calculatedCardWidth,
                                  titleLines: [
                                    'Personal',
                                    'Development',
                                    'Hub',
                                  ],
                                  buttonText: 'Launch',
                                  url: 'https://pdh-web-app.onrender.com',
                                  moduleKey: 'pdh',
                                ),
                              );
                            }
                            if (showSkillsHeatmap) {
                              if (topRow.isNotEmpty) {
                                topRow.add(const SizedBox(width: 18.0));
                              }
                              topRow.add(
                                _buildModuleCard(
                                  context: context,
                                  cardWidth: calculatedCardWidth,
                                  titleLines: [
                                    'Resource',
                                    'Capacity &',
                                    'Skills heatmap',
                                  ],
                                  buttonText: 'Launch',
                                  url:
                                      'https://resource-capacity.netlify.app/',
                                  moduleKey: 'skills_heatmap',
                                ),
                              );
                            }
                            if (showRecruitment) {
                              if (topRow.isNotEmpty) {
                                topRow.add(const SizedBox(width: 18.0));
                              }
                              topRow.add(
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

                            final List<Widget> bottomRow = [];
                            if (showSOWBuilder) {
                              bottomRow.add(
                                _buildModuleCard(
                                  context: context,
                                  cardWidth: calculatedCardWidth,
                                  titleLines: ['Proposal &', 'SOW Builder'],
                                  buttonText: 'Launch',
                                  url:
                                      'https://proposal-and-sow-builder.onrender.com',
                                  moduleKey: 'sow_builder',
                                ),
                              );
                            }
                            if (bottomRow.isNotEmpty) {
                              bottomRow.add(const SizedBox(width: 18.0));
                            }
                            bottomRow.add(
                              _buildModuleCard(
                                context: context,
                                cardWidth: calculatedCardWidth,
                                titleLines: [
                                  'Deliverables & Sprint',
                                  'Sign Off Hub',
                                ],
                                buttonText: 'Coming Soon',
                                url: '',
                                moduleKey: 'deliverable_sprint',
                                isComingSoon: true,
                              ),
                            );

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (topRow.isNotEmpty)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: topRow,
                                  ),
                                if (topRow.isNotEmpty && bottomRow.isNotEmpty)
                                  const SizedBox(height: 18.0),
                                if (bottomRow.isNotEmpty)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: bottomRow,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
    bool isComingSoon = false,
  }) {
    return _HoverableModuleCard(
      context: context,
      cardWidth: cardWidth,
      titleLines: titleLines,
      subtitle: subtitle,
      buttonText: buttonText,
      url: url,
      moduleKey: moduleKey,
      isComingSoon: isComingSoon,
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
  final bool isComingSoon;

  const _HoverableModuleCard({
    required this.context,
    required this.cardWidth,
    required this.titleLines,
    this.subtitle,
    required this.buttonText,
    required this.url,
    required this.moduleKey,
    this.isComingSoon = false,
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
    return Container(
      width: widget.cardWidth * 1.1,
      height: 400,
      padding: EdgeInsets.all(widget.cardWidth * 0.05),
      child: MouseRegion(
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
          alignment: Alignment.center,
          child: SizedBox(
            width: widget.cardWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: widget.cardWidth,
                    padding: const EdgeInsets.all(28.8),
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
                                padding: const EdgeInsets.only(bottom: 3.6),
                                child: Text(
                                  line,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: widget.cardWidth > 300
                                        ? 23.4
                                        : widget.cardWidth > 200
                                        ? 19.8
                                        : 16.2,
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
                            const SizedBox(height: 10.8),
                            Text(
                              widget.subtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: primaryAccent,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (_lastAccessedText != null) ...[
                            const SizedBox(height: 10.8),
                            Text(
                              _lastAccessedText!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.6,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28.8),
                          ElevatedButton(
                            onPressed: widget.isComingSoon
                                ? null
                                : (_isLoading
                                      ? null
                                      : () async {
                                          setState(() => _isLoading = true);
                                          try {
                                            await _launchUrlFromContext(
                                              widget.context,
                                              widget.url,
                                              widget.moduleKey,
                                            );

                                            await _loadLastAccessed();
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                () => _isLoading = false,
                                              );
                                            }
                                          }
                                        }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.isComingSoon
                                  ? Colors.grey.shade600
                                  : primaryAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 36.0,
                                vertical: 14.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(45.0),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16.2,
                                fontWeight: FontWeight.bold,
                              ),
                              elevation: widget.isComingSoon ? 0 : 10,
                              shadowColor: widget.isComingSoon
                                  ? Colors.transparent
                                  : primaryAccent.withValues(alpha: 0.5),
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
}

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
      return 'Last accessed: ${DateFormat('MMM d, yyyy').format(lastAccessed)}';
    } else if (difference.inDays > 0) {
      final days = difference.inDays;
      return 'Last accessed: $days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return 'Last accessed: $hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      final minutes = difference.inMinutes;
      return 'Last accessed: $minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Last accessed: Just now';
    }
  } catch (e) {
    debugPrint('Error getting last accessed time: $e');
    return null;
  }
}

Future<void> _launchUrlFromContext(
  BuildContext context,
  String url,
  String moduleKey,
) async {
  try {
    String secureUrl = url.trim();
    if (secureUrl.startsWith('http://')) {
      secureUrl = secureUrl.replaceFirst('http://', 'https://');
    } else if (!secureUrl.startsWith('https://')) {
      secureUrl = 'https://$secureUrl';
    }

    final bool isPDHUrl =
        secureUrl.contains('pdh-web-app.onrender.com') ||
        secureUrl.contains('pdh');
    final bool isSOWBuilderUrl =
        secureUrl.contains('proposal-and-sow-builder.onrender.com') ||
        secureUrl.contains('sow_builder') ||
        secureUrl.contains('sow-builder');
    final bool requiresToken = isPDHUrl || isSOWBuilderUrl;

    String? token;
    if (requiresToken) {
      final authProvider = context.read<AuthProvider>();

      if (authProvider.userEmail != null) {
        token = authProvider.userToken;

        if (token == null || token.isEmpty) {
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

    Uri uri = Uri.parse(secureUrl);
    if (requiresToken && token != null && token.isNotEmpty) {
      uri = uri.replace(queryParameters: {'token': token});
    }

    debugPrint('[ModuleLaunch] Launching URL for $moduleKey: $uri');

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!context.mounted) return;
    if (launched) {
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
