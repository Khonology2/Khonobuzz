import 'package:flutter/material.dart';
import '../theme/app_backgrounds.dart';
import '../theme/app_text_colors.dart';
import '../services/sound_system.dart';

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

/// Module cards: light mode uses frosted panels like [EntityManagementScreen]; dark uses `0xFF3D3F40` blend like other admin screens.
class LearnMoreScreen extends StatelessWidget {
  const LearnMoreScreen({super.key});

  static const double _colGap = 12.0;

  /// Same dark “widget panel” as `entityDarkWidgetBg` in entity/module screens.
  static final Color _darkPanelBg = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.10),
    const Color(0xFF3D3F40).withValues(alpha: 0.40),
  );

  void _goBackToLanding(BuildContext context) {
    SoundSystem.playButtonClick();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildPrimaryPill({required VoidCallback onPressed}) {
    return Semantics(
      label: 'BACK',
      button: true,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: const Color(0xFFC10D00),
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

  /// Row 1: PDH | heatmap. Row 2: recruitment | proposal. Row 3: deliverables centered under both.
  Widget _buildModuleGrid(BuildContext context) {
    final s = _kModuleSegments;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildModuleCard(context, s[0])),
            const SizedBox(width: _colGap),
            Expanded(child: _buildModuleCard(context, s[1])),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildModuleCard(context, s[2])),
            const SizedBox(width: _colGap),
            Expanded(child: _buildModuleCard(context, s[3])),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 1),
            Expanded(
              flex: 2,
              child: _buildModuleCard(context, s[4]),
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
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Image.asset('assets/images/khono.png', height: 88),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentMax),
                            child: _buildModuleGrid(context),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: _buildPrimaryPill(
                            onPressed: () => _goBackToLanding(context),
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
