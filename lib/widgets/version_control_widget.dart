import 'dart:async';
import 'package:flutter/material.dart';
import 'package:khonobuzz/services/version_service.dart';

/// Version control widget: displays Ver YYYY.MM.[W][D][n] SIT (W=week A-E, D=weekday A-E Mon-Fri, n=commits).
/// Tooltip shows latest feature release, date, and commits since release.
/// Version only updates when commits are pushed (no automatic date change).
class VersionControlWidget extends StatefulWidget {
  const VersionControlWidget({
    super.key,
    this.fontSize = 12.0,
    this.textColor = Colors.white70,
    this.hoverColor = Colors.white,
  });

  final double fontSize;
  final Color textColor;
  final Color hoverColor;

  @override
  State<VersionControlWidget> createState() => _VersionControlWidgetState();
}

class _VersionControlWidgetState extends State<VersionControlWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _scaleAnimation;
  late Timer _refreshTimer;
  String _currentVersion = 'Ver 2026.03.BA1 SIT';
  String _tooltipMessage = 'Loading version...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _colorAnimation = ColorTween(
      begin: widget.textColor,
      end: widget.hoverColor,
    ).animate(_animationController);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadVersion();
    });

    _loadVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      VersionService.clearCache();
      _loadVersion();
    }
  }

  Future<void> _loadVersion() async {
    try {
      final data = await VersionService.loadVersion();

      if (mounted) {
        setState(() {
          _currentVersion = _formatDisplayVersion(data.version);
          _tooltipMessage = _buildTooltip(data);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tooltipMessage = 'Failed to load version';
        });
      }
    }
  }

  /// Display: Ver YYYY.MM.[W][D][n] SIT (W=week A-E, D=weekday A-E Mon-Fri, n=commits; SIT fixed)
  String _formatDisplayVersion(String version) {
    return 'Ver $version SIT';
  }

  /// Tooltip: Latest Feature Release, Date of Feature Commit, Commits since release.
  /// Only feature commits are reflected (stored in version.json by workflow).
  String _buildTooltip(VersionData data) {
    final buffer = StringBuffer();

    buffer.writeln('Latest Feature Release');
    buffer.writeln();

    if (data.lastFeatureCommit.isNotEmpty) {
      buffer.writeln('Latest Feature:');
      buffer.writeln(data.lastFeatureCommit);
      buffer.writeln();
    }

    if (data.featureDate.isNotEmpty) {
      buffer.writeln('Released:');
      buffer.writeln(data.featureDate);
      buffer.writeln();
    }

    buffer.writeln('Commits since release:');
    buffer.write(data.commitCountSinceFeature);

    return buffer.toString();
  }

  void _onHover(bool isHovering) {
    if (isHovering) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Tooltip(
        message: _tooltipMessage,
        textAlign: TextAlign.left,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Poppins',
          height: 1.4,
        ),
        showDuration: const Duration(seconds: 10),
        waitDuration: const Duration(milliseconds: 500),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                _currentVersion,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  color: _colorAnimation.value,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Poppins',
                  letterSpacing: 0.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
