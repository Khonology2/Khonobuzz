import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/modules_ping_service.dart';
import '../services/sound_system.dart';
import '../theme/app_backgrounds.dart';
import '../providers/theme_mode_provider.dart';
import '../theme/app_text_colors.dart';
import '../widgets/floating_circles_particle_animation.dart';

const Color primaryAccent = Color(0xFFC10D00);
const Color moduleCardDarkSurface = Color(0xFF3D3F40);
const Duration _moduleTokenFetchTimeout = Duration(milliseconds: 1800);
final Map<String, String> _moduleLaunchTokenCache = <String, String>{};

class ModuleScreen extends StatefulWidget {
  const ModuleScreen({super.key});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  bool _isLoadingModuleAccess = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _moduleAccessPollTimer;

  @override
  void initState() {
    super.initState();

    _loadModuleAccess();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Pick up module changes from admins without logging out (matches admin refresh cadence).
      _moduleAccessPollTimer = Timer.periodic(const Duration(minutes: 3), (_) {
        if (!mounted) return;
        context.read<AuthProvider>().refreshModuleAccessFromServer();
      });
    });
  }

  @override
  void dispose() {
    _moduleAccessPollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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
              } else if (trimmed.startsWith(
                'Deliverables & Sprint Sign-Off Hub',
              )) {
                if (!moduleNames.contains(
                  'Deliverables & Sprint Sign-Off Hub',
                )) {
                  moduleNames.add('Deliverables & Sprint Sign-Off Hub');
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
    context.watch<ThemeModeProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              appBackgroundAsset(context),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll<Color>(
                  appTextColor(context),
                ),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Center(
                    child: Transform.scale(
                      scale: 0.8,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final authProvider = context.watch<AuthProvider>();

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
                            final hasPDHAccess =
                                authProvider.hasModuleAccess('PDH') ||
                                authProvider.hasModuleAccess(
                                  'Personal Development Hub',
                                );
                            final hasSkillsHeatmapAccess =
                                authProvider.hasModuleAccess(
                                  'Skills Heatmap',
                                ) ||
                                authProvider.hasModuleAccess(
                                  'Resource & Capacity Skills Heatmap',
                                );
                            final hasRecruitmentAccess =
                                authProvider.hasModuleAccess(
                                  'Automated Recruitment Workflow',
                                ) ||
                                authProvider.hasModuleAccess('Recruitment');
                            final hasSOWBuilderAccess =
                                authProvider.hasModuleAccess(
                                  'Proposal & SOW Builder',
                                ) ||
                                authProvider.hasModuleAccess('SOW Builder');

                            final showPDH = isAdmin || hasPDHAccess;
                            final showSkillsHeatmap =
                                isAdmin || hasSkillsHeatmapAccess;
                            final hasDeliverablesAccess = authProvider
                                .hasModuleAccess(
                                  'Deliverables & Sprint Sign-Off Hub',
                                );

                            final showRecruitment =
                                isAdmin || hasRecruitmentAccess;
                            final showSOWBuilder =
                                isAdmin || hasSOWBuilderAccess;
                            final showDeliverables =
                                isAdmin || hasDeliverablesAccess;

                            if (!showPDH &&
                                !showSkillsHeatmap &&
                                !showRecruitment &&
                                !showSOWBuilder &&
                                !showDeliverables) {
                              return Center(
                                child: Text(
                                  'No module access assigned. Please contact your administrator.',
                                  style: TextStyle(
                                    color: appTextColor(context),
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
                                  buttonText: 'LAUNCH',
                                  url:
                                      'https://personal-development-hub.onrender.com',
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
                                  buttonText: 'LAUNCH',
                                  url: 'https://resource-capacity.netlify.app/',
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
                                  buttonText: 'LAUNCH',
                                  url: 'https://recruitment-web-59qy.onrender.com/',
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
                                  buttonText: 'LAUNCH',
                                  url: 'https://lukens-ivdu.onrender.com',
                                  moduleKey: 'sow_builder',
                                ),
                              );
                            }
                            if (showDeliverables) {
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
                                  buttonText: 'LAUNCH',
                                  url: 'https://flow-space-1.onrender.com/',
                                  moduleKey: 'deliverable_sprint',
                                  isComingSoon: false,
                                ),
                              );
                            }

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (topRow.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: topRow,
                                  ),
                                if (topRow.isNotEmpty && bottomRow.isNotEmpty)
                                  const SizedBox(height: 18.0),
                                if (bottomRow.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey =
      GlobalKey();
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
    final String? description = _getModuleDescription(widget.moduleKey);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.10),
            moduleCardDarkSurface.withValues(alpha: 0.40),
          )
        : Colors.white.withValues(alpha: 0.40);
    final Color titleColor = appTextColor(context);
    final Color secondaryTextColor =
        isDark ? appTextColor(context).withValues(alpha: 0.85) : Colors.black87;
    final Color borderColor = _isHovered
        ? (isDark ? Colors.white54 : Colors.black45)
        : (isDark ? Colors.white24 : Colors.black26);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool hasBoundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final double targetHeight =
            hasBoundedHeight && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 400;
        return Container(
          width: widget.cardWidth * 1.1,
          height: targetHeight,
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
                      Positioned.fill(
                        child: IgnorePointer(
                          child: FloatingCirclesParticleAnimation(
                            key: _animationKey,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: widget.cardWidth,
                        padding: const EdgeInsets.all(28.8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: borderColor,
                            width: _isHovered ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isHovered
                                  ? Colors.black.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.22),
                              blurRadius: _isHovered ? 35 : 25,
                              offset: Offset(0, _isHovered ? 15 : 10),
                              spreadRadius: _isHovered ? 2 : 0,
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, innerConstraints) {
                            return SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: innerConstraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          titleColor,
                                          BlendMode.srcIn,
                                        ),
                                        child: Image.asset(
                                          'assets/images/khonology_white_logo.png',
                                          height: 40,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16.0),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: widget.titleLines.map((line) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 3.6,
                                          ),
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
                                              color: titleColor,
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
                                          fontWeight: FontWeight.w500,
                                          color: secondaryTextColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18.0),
                                    if (description != null &&
                                        description.isNotEmpty) ...[
                                      Text(
                                        description,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: secondaryTextColor,
                                          fontFamily: 'Poppins',
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 18.0),
                                    ],
                                    ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              SoundSystem.playButtonClick();
                                              _animationKey.currentState
                                                  ?.triggerParticleExplosion();

                                              if (widget.isComingSoon) {
                                                if (!mounted) {
                                                  return;
                                                }
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Deliverables & Sprint Sign-Off Hub is coming soon.',
                                                      style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              setState(() => _isLoading = true);
                                              try {
                                                await _launchUrlFromContext(
                                                  widget.context,
                                                  widget.url,
                                                  widget.moduleKey,
                                                );
                                                if (mounted) {
                                                  setState(() {
                                                    _lastAccessedText =
                                                        'Last accessed: Just now';
                                                  });
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _isLoading = false,
                                                  );
                                                }
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 36.0,
                                          vertical: 14.4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            45.0,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16.2,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        elevation: widget.isComingSoon ? 0 : 10,
                                        shadowColor: widget.isComingSoon
                                            ? Colors.transparent
                                            : primaryAccent.withValues(
                                                alpha: 0.5,
                                              ),
                                      ),
                                      child: Text(widget.buttonText),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
      },
    );
  }
}

String? _getModuleDescription(String moduleKey) {
  switch (moduleKey) {
    case 'pdh':
      return 'Track Progress, Unlock Achievements, and Gamification.';
    case 'skills_heatmap':
      return 'Visualising Availability vs Pipeline Demand for Proactive Staffing Decisions.';
    case 'sow_builder':
      return 'End-to-End Proposal Generation and Sign-Off in One Tool.';
    case 'recruitment':
      return 'Streamlining CV Screening, Initial Assessments, and Shortlisting in One Tool.';
    case 'deliverable_sprint':
      return 'Visualising Sprint Performance, and Capturing Client Approval.';
    default:
      return null;
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
    ModulesPingService.pingOnModuleLaunch();

    String secureUrl = url.trim();
    if (secureUrl.startsWith('http://')) {
      secureUrl = secureUrl.replaceFirst('http://', 'https://');
    } else if (!secureUrl.startsWith('https://')) {
      secureUrl = 'https://$secureUrl';
    }

    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final isLightMode = context.read<ThemeModeProvider>().isLight;
    final theme = isLightMode ? 'light' : 'dark';
    final String? existingToken = authProvider.userToken;
    if (existingToken == null || existingToken.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Authentication token is missing. Please log in again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
      );
      return;
    }

    String token = existingToken;
    final email = authProvider.userEmail;
    if (email == null || email.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User email is missing. Please log in again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
      );
      return;
    }

    final String cacheKey = '$moduleKey:$email:$theme';
    String? latestModuleAccessRole;
    try {
      final userByEmailUri = Uri.parse(ApiConfig.userByEmailEndpoint(email));
      final userByEmailRes = await http
          .get(
            userByEmailUri,
            headers: {
              'Authorization': 'Bearer $existingToken',
              'Accept': 'application/json',
            },
          )
          .timeout(_moduleTokenFetchTimeout);
      if (userByEmailRes.statusCode == 200) {
        final payload = json.decode(userByEmailRes.body);
        if (payload is Map<String, dynamic>) {
          final userMap = (payload['user'] is Map<String, dynamic>)
              ? payload['user'] as Map<String, dynamic>
              : payload;
          latestModuleAccessRole = userMap['moduleAccessRole'] as String?;
        }
      }
    } catch (e) {
      debugPrint('[ModuleLaunch] Could not refresh moduleAccessRole: $e');
    }

    Future<String?> fetchLatestToken({
      required String tokenEndpoint,
    }) async {
      const int maxAttempts = 5;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final response = await http
              .get(
                Uri.parse(tokenEndpoint),
                headers: {
                  'Authorization': 'Bearer $existingToken',
                  'Accept': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) {
            final body = json.decode(response.body);
            if (body is Map<String, dynamic>) {
              final freshToken = body['token'] as String?;
              if (freshToken != null && freshToken.isNotEmpty) {
                return freshToken;
              }
            }
          }
          debugPrint(
            '[ModuleLaunch] Token fetch attempt $attempt/$maxAttempts failed '
            '(status ${response.statusCode})',
          );
        } catch (e) {
          debugPrint(
            '[ModuleLaunch] Token fetch attempt $attempt/$maxAttempts error: $e',
          );
        }
        if (attempt < maxAttempts) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      return null;
    }

    if (moduleKey == 'recruitment') {
      final fresh = await fetchLatestToken(
        tokenEndpoint: ApiConfig.authTokenEndpoint(
          email,
          module: 'recruitment',
          theme: theme,
        ),
      );
      if (fresh == null || fresh.isEmpty) {
        return;
      }
      token = fresh;
      _moduleLaunchTokenCache[cacheKey] = fresh;
      debugPrint('[ModuleLaunch] Using latest ARW token for recruitment app');
    } else if (moduleKey == 'skills_heatmap') {
      String? selectedRole;
      try {
        final roleSource = latestModuleAccessRole;
        if (roleSource != null && roleSource.isNotEmpty) {
          final parts = roleSource.split(',');
          for (final part in parts) {
            final trimmedPart = part.trim();
            if (trimmedPart.startsWith('Skills Heatmap - ')) {
              selectedRole = trimmedPart.replaceFirst('Skills Heatmap - ', '').trim();
              break;
            }
          }
        }
        if ((selectedRole == null || selectedRole.isEmpty) &&
            userProvider.users.isNotEmpty) {
          final currentUser = userProvider.users.firstWhere(
            (u) => u.email.toLowerCase() == email.toLowerCase(),
            orElse: () => throw StateError('Current user not found'),
          );
          final localRole = currentUser.moduleAccessRole;
          if (localRole != null && localRole.isNotEmpty) {
            final parts = localRole.split(',');
            for (final part in parts) {
              final trimmedPart = part.trim();
              if (trimmedPart.startsWith('Skills Heatmap - ')) {
                selectedRole = trimmedPart.replaceFirst('Skills Heatmap - ', '').trim();
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ModuleLaunch] Error getting skills heatmap role: $e');
      }
      selectedRole = (selectedRole == null || selectedRole.isEmpty)
          ? 'Executive'
          : selectedRole;

      final String skillsCacheKey = '$moduleKey:$email:$selectedRole:$theme';
      final fresh = await fetchLatestToken(
        tokenEndpoint: ApiConfig.authTokenEndpoint(
          email,
          module: 'skills_heatmap',
          role: selectedRole,
          theme: theme,
        ),
      );
      if (fresh == null || fresh.isEmpty) {
        return;
      }
      token = fresh;
      _moduleLaunchTokenCache[skillsCacheKey] = fresh;
      debugPrint(
        '[ModuleLaunch] Using latest skills heatmap token with role: $selectedRole',
      );
    } else if (moduleKey == 'deliverable_sprint') {
      String? selectedRole;
      try {
        final roleSource = latestModuleAccessRole;
        if (roleSource != null && roleSource.isNotEmpty) {
          final parts = roleSource.split(',');
          for (final part in parts) {
            final trimmedPart = part.trim();
            if (trimmedPart.startsWith('Deliverables & Sprint Sign-Off Hub - ')) {
              selectedRole = trimmedPart
                  .replaceFirst('Deliverables & Sprint Sign-Off Hub - ', '')
                  .trim();
              break;
            }
          }
        }
        if ((selectedRole == null || selectedRole.isEmpty) &&
            userProvider.users.isNotEmpty) {
          final currentUser = userProvider.users.firstWhere(
            (u) => u.email.toLowerCase() == email.toLowerCase(),
            orElse: () => throw StateError('Current user not found'),
          );
          final localRole = currentUser.moduleAccessRole;
          if (localRole != null && localRole.isNotEmpty) {
            final parts = localRole.split(',');
            for (final part in parts) {
              final trimmedPart = part.trim();
              if (trimmedPart.startsWith('Deliverables & Sprint Sign-Off Hub - ')) {
                selectedRole = trimmedPart
                    .replaceFirst('Deliverables & Sprint Sign-Off Hub - ', '')
                    .trim();
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ModuleLaunch] Error getting deliverables role: $e');
      }
      selectedRole = (selectedRole == null || selectedRole.isEmpty)
          ? 'Team member'
          : selectedRole;

      final String deliverablesCacheKey =
          '$moduleKey:$email:$selectedRole:$theme';
      final fresh = await fetchLatestToken(
        tokenEndpoint: ApiConfig.authTokenEndpoint(
          email,
          module: 'deliverable_sprint',
          role: selectedRole,
          theme: theme,
        ),
      );
      if (fresh == null || fresh.isEmpty) {
        return;
      }
      token = fresh;
      _moduleLaunchTokenCache[deliverablesCacheKey] = fresh;
      debugPrint(
        '[ModuleLaunch] Using latest deliverables token with role: $selectedRole',
      );
    } else if (moduleKey == 'sow_builder') {
      String? selectedRole;
      try {
        final roleSource = latestModuleAccessRole;
        if (roleSource != null && roleSource.isNotEmpty) {
          final parts = roleSource.split(',');
          for (final part in parts) {
            final trimmedPart = part.trim();
            if (trimmedPart.startsWith('Proposal & SOW Builder - ')) {
              selectedRole = trimmedPart
                  .replaceFirst('Proposal & SOW Builder - ', '')
                  .trim();
              break;
            }
          }
        }
        if ((selectedRole == null || selectedRole.isEmpty) &&
            userProvider.users.isNotEmpty) {
          final currentUser = userProvider.users.firstWhere(
            (u) => u.email.toLowerCase() == email.toLowerCase(),
            orElse: () => throw StateError('Current user not found'),
          );
          final localRole = currentUser.moduleAccessRole;
          if (localRole != null && localRole.isNotEmpty) {
            final parts = localRole.split(',');
            for (final part in parts) {
              final trimmedPart = part.trim();
              if (trimmedPart.startsWith('Proposal & SOW Builder - ')) {
                selectedRole = trimmedPart
                    .replaceFirst('Proposal & SOW Builder - ', '')
                    .trim();
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ModuleLaunch] Error getting SOW Builder persona: $e');
      }
      selectedRole =
          (selectedRole == null || selectedRole.isEmpty) ? 'Manager' : selectedRole;

      final String sowCacheKey =
          '$moduleKey:$email:$selectedRole:$theme';
      final fresh = await fetchLatestToken(
        tokenEndpoint: ApiConfig.authTokenEndpoint(
          email,
          module: 'sow_builder',
          role: selectedRole,
          theme: theme,
        ),
      );
      if (fresh == null || fresh.isEmpty) {
        return;
      }
      token = fresh;
      _moduleLaunchTokenCache[sowCacheKey] = fresh;
      debugPrint(
        '[ModuleLaunch] Using latest SOW Builder token with persona: $selectedRole',
      );
    } else {
      final fresh = await fetchLatestToken(
        tokenEndpoint: ApiConfig.authTokenEndpoint(email, theme: theme),
      );
      if (fresh == null || fresh.isEmpty) {
        return;
      }
      token = fresh;
      _moduleLaunchTokenCache[cacheKey] = fresh;
    }

    final Uri uri;
    if (moduleKey == 'recruitment') {
      // Hash-router SPA: .../#/splash?token=... (not /splash?token=... on the server path)
      final base = Uri.parse(secureUrl);
      final fragmentPath = Uri(
        path: '/splash',
        queryParameters: <String, String>{'token': token},
      );
      uri = Uri(
        scheme: base.scheme,
        host: base.host,
        path: '/',
        fragment: fragmentPath.toString(),
      );
    } else {
      var built = Uri.parse(secureUrl);
      final existingParams = Map<String, String>.from(built.queryParameters);
      existingParams['token'] = token;
      built = built.replace(queryParameters: existingParams);
      uri = built;
    }

    debugPrint('[ModuleLaunch] Launching URL for $moduleKey: $uri');

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!context.mounted) return;
    if (launched) {
      unawaited(_saveLastAccessedTime(moduleKey));
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
