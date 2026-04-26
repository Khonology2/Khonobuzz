import 'package:flutter/material.dart';
import '../theme/app_backgrounds.dart';
import '../theme/app_text_colors.dart';
import '../services/sound_system.dart';
import '../services/version_service.dart';

/// Copy matches [lib/screens/module_screen.dart] + [_getModuleDescription].
class _ModuleSegment {
  const _ModuleSegment({required this.title, required this.body});

  final String title;
  final String body;
}

const List<_ModuleSegment> _kModuleSegments = [
  _ModuleSegment(
    title: 'PERSONAL DEVELOPMENT HUB',
    body: 'Track Progress, Unlock Achievements, and Gamification.',
  ),
  _ModuleSegment(
    title: 'RESOURCE, CAPACITY & SKILLS HEATMAP',
    body:
        'Visualising Availability vs Pipeline Demand for Proactive Staffing Decisions.',
  ),
  _ModuleSegment(
    title: 'AUTOMATED RECRUITMENT WORKFLOW',
    body:
        'Streamlining CV Screening, Initial Assessments, and Shortlisting in One Tool.',
  ),
  _ModuleSegment(
    title: 'PROPOSAL & SOW BUILDER',
    body: 'End-to-End Proposal Generation and Sign-Off in One Tool.',
  ),
  _ModuleSegment(
    title: 'DELIVERABLES & SPRINT SIGN-OFF HUB',
    body: 'Visualising Sprint Performance, and Capturing Client Approval.',
  ),
];

const Color _kBrandRed = Color(0xFFC10D00);

class LearnMoreScreen extends StatefulWidget {
  const LearnMoreScreen({super.key});

  @override
  State<LearnMoreScreen> createState() => _LearnMoreScreenState();
}

class _LearnMoreScreenState extends State<LearnMoreScreen>
    with TickerProviderStateMixin {
  static const double _colGap = 12.0;

  late final AnimationController _entranceController;
  VersionData? _version;

  static final Color _darkPanelBg = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.10),
    const Color(0xFF3D3F40).withValues(alpha: 0.40),
  );

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    VersionService.loadVersion().then((d) {
      if (mounted) {
        setState(() => _version = d);
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _goBackToLanding() {
    SoundSystem.playButtonClick();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 0..1 in [start, end] of controller 0..1
  static double _intervalPhase(
    double value,
    double start,
    double end, {
    double begin = 0.0,
    double finish = 1.0,
  }) {
    if (value <= start) {
      return begin;
    }
    if (value >= end) {
      return finish;
    }
    return begin +
        (finish - begin) *
            Curves.easeOutCubic.transform((value - start) / (end - start));
  }

  /// Staggered fade + slight upward slide for module cards.
  Widget _staggeredCard(Widget child, int index) {
    const step = 0.10;
    const window = 0.32;
    final start = index * step;

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final v = _entranceController.value;
        final t = v <= start
            ? 0.0
            : v >= start + window
            ? 1.0
            : Curves.easeOutCubic.transform((v - start) / window);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  /// FAQ + hint + version block fades in after cards.
  Widget _revealBlock({required Widget child}) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final t = _intervalPhase(
          _entranceController.value,
          0.48,
          0.88,
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildPrimaryPill({required VoidCallback onPressed}) {
    return Semantics(
      label: 'BACK',
      button: true,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: _kBrandRed,
          borderRadius: BorderRadius.circular(50.0),
        ),
        child: MaterialButton(
          onPressed: onPressed,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: const Text(
            'BACK',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Thin 1–5 step track (static tour affordance).
  Widget _buildStepStrip(BuildContext context) {
    final label = appTextColor(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        children: [
          for (int i = 0; i < 5; i++) ...[
            if (i > 0)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: _kBrandRed.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBrandRed, width: 1.5),
                    color: _kBrandRed.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: label,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Minimal side-rail: narrow column + red “Modules” pill to mirror [SideMenu].
  Widget _buildSideMenuHintIllustration(bool isDark) {
    final rail = isDark
        ? const Color(0xFF1E1E1E)
        : Colors.white.withValues(alpha: 0.55);
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      decoration: BoxDecoration(
        color: rail,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _hintMenuLine(false),
          const SizedBox(height: 4),
          _hintMenuLine(false),
          const SizedBox(height: 4),
          _hintMenuLine(true),
          const SizedBox(height: 4),
          _hintMenuLine(false),
        ],
      ),
    );
  }

  Widget _hintMenuLine(bool active) {
    return Container(
      height: 5,
      width: double.infinity,
      decoration: BoxDecoration(
        color: active
            ? _kBrandRed
            : const Color(0x1AC10D00),
        borderRadius: BorderRadius.circular(3),
        border: active
            ? null
            : Border.all(
                color: _kBrandRed.withValues(alpha: 0.2),
                width: 0.5,
              ),
      ),
    );
  }

  Widget _buildLaunchHintRow(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSideMenuHintIllustration(isDark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "You'll open these from the Modules screen after sign-in, using the side menu (Modules is the launch point for all products).",
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              height: 1.45,
              color: appTextColor(context).withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }

  String _contentUpdatedLine() {
    final v = _version;
    if (v == null) {
      return 'Content updated: …';
    }
    if (v.featureDate.isNotEmpty) {
      return 'Content updated: ${v.featureDate} · ${v.version}';
    }
    return 'Content updated: ${v.version}';
  }

  Widget _buildFaqSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? _darkPanelBg : Colors.white.withValues(alpha: 0.40);
    const divider = Colors.transparent;

    Widget tile(String title, String body) {
      return Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: divider),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: panel,
            collapsedBackgroundColor: panel,
            title: Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: appTextColor(context),
              ),
            ),
            children: [
              Text(
                body,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark
                      ? const Color(0xFFCCCCCC)
                      : appTextColor(context).withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Common questions',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: appTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        tile(
          'Which email can I use to sign in?',
          'Sign-in is limited to your Khonology work account (@khonology.com), consistent with the rest of the app.',
        ),
        const SizedBox(height: 6),
        tile(
          'Who assigns module access?',
          'A Khonology administrator uses Module Access in the app to choose which products you can open. You only see cards you are allowed to use.',
        ),
        const SizedBox(height: 6),
        tile(
          'How do I open PDH, Recruitment, and the other products?',
          'After you sign in, go to the Modules page from the left-hand side menu, then use Launch on each product you have access to.',
        ),
        const SizedBox(height: 6),
        tile(
          'Who do I contact if something is wrong?',
          'Contact your line manager or Khonology IT / admin for access changes or if a module will not open.',
        ),
        const SizedBox(height: 6),
        tile(
          'Do I need to install anything else to use a module?',
          'No separate install is required for each product. After you tap Launch on the Modules screen, the app opens that product in your browser. Use a supported, up-to-date browser for the best experience.',
        ),
      ],
    );
  }

  Widget _buildModuleCard(BuildContext context, _ModuleSegment segment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = appTextColor(context);
    final bodyColor = isDark
        ? const Color(0xFFCCCCCC)
        : appTextColor(context).withValues(alpha: 0.88);
    final cardBg = isDark ? _darkPanelBg : Colors.white.withValues(alpha: 0.40);
    final dividerColor =
        isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.20);
    final shadowColor =
        isDark ? Colors.black.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.10);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: isDark ? 12 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            segment.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: titleColor,
              height: 1.3,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            segment.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: bodyColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 48,
              height: 2,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    final s = _kModuleSegments;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _staggeredCard(_buildModuleCard(context, s[0]), 0)),
            const SizedBox(width: _colGap),
            Expanded(child: _staggeredCard(_buildModuleCard(context, s[1]), 1)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _staggeredCard(_buildModuleCard(context, s[2]), 2)),
            const SizedBox(width: _colGap),
            Expanded(child: _staggeredCard(_buildModuleCard(context, s[3]), 3)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 1),
            Expanded(
              flex: 2,
              child: _staggeredCard(_buildModuleCard(context, s[4]), 4),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(appBackgroundAsset(context)),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final minH = constraints.maxHeight;
              final contentMax = (maxW * 0.92).clamp(280.0, 720.0);

              return SingleChildScrollView(
                clipBehavior: Clip.none,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minH),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Image.asset('assets/images/khono.png', height: 88),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentMax),
                            child: _buildStepStrip(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentMax),
                            child: _buildModuleGrid(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentMax),
                            child: _revealBlock(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLaunchHintRow(isDark),
                                  const SizedBox(height: 20),
                                  _buildFaqSection(context),
                                  const SizedBox(height: 10),
                                  Text(
                                    _contentUpdatedLine(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: appTextColor(context).withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: _buildPrimaryPill(
                            onPressed: _goBackToLanding,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Image.asset(
                            isLight
                                ? 'assets/images/red_disc.png'
                                : 'assets/images/discs.png',
                            height: isLight ? 110 : 72,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
