import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:khonobuzz/services/version_service.dart';

const String _kVersionControlLastSeenKey = 'version_control_last_seen_version';

/// Version control widget: displays Ver YYYY.MM.[W][D][n] SIT (W=week 1-4 A-D, D=weekday A-E Mon-Fri; weekend not counted).
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
  // Prevent multiple widgets/screens from repeatedly triggering version loads.
  // This ensures we fetch the version only once per app process (with a few
  // retries if the service throws).
  static Future<VersionData>? _sessionVersionFuture;
  static int _sessionVersionAttempts = 0;

  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _scaleAnimation;
  String _currentVersion = 'Ver 2026.03.AB1 SIT';
  String _tooltipMessage = 'Loading version...';
  String? _rawVersion;
  bool _showAttentionCatcher = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadVersion();
  }

  @override
  void didUpdateWidget(VersionControlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textColor != widget.textColor ||
        oldWidget.hoverColor != widget.hoverColor) {
      _colorAnimation = ColorTween(
        begin: widget.textColor,
        end: widget.hoverColor,
      ).animate(_animationController);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadVersion();
    }
  }

  Future<void> _loadVersion() async {
    try {
      final data = await _getVersionOncePerSession();
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_kVersionControlLastSeenKey);
      final isNewVersion = data.version != lastSeen;

      if (mounted) {
        setState(() {
          _rawVersion = data.version;
          _currentVersion = _formatDisplayVersion(data.version);
          _tooltipMessage = _buildTooltip(data);
          _showAttentionCatcher = isNewVersion;
        });
        if (isNewVersion) {
          _pulseController.repeat(reverse: true);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tooltipMessage = 'Failed to load version';
        });
      }
    }
  }

  Future<VersionData> _getVersionOncePerSession() async {
    // If we already kicked off a load (and it hasn't failed), reuse it.
    final existing = _sessionVersionFuture;
    if (existing != null) return existing;

    // Retry a few times if the underlying service throws.
    _sessionVersionAttempts++;
    if (_sessionVersionAttempts > 3) {
      // Give callers the best-effort fallback from the service.
      return VersionService.loadVersion();
    }

    try {
      _sessionVersionFuture = VersionService.loadVersion();
      return await _sessionVersionFuture!;
    } catch (_) {
      // Allow a retry on the next widget attempt.
      _sessionVersionFuture = null;
      rethrow;
    }
  }

  Future<void> _onSeenByUser() async {
    if (!_showAttentionCatcher || _rawVersion == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVersionControlLastSeenKey, _rawVersion!);
    if (mounted) {
      _pulseController.stop();
      _pulseController.reset();
      setState(() => _showAttentionCatcher = false);
    }
  }

  /// Display: Ver YYYY.MM.[W][D][n] SIT (W=week 1-4 A-D, D=weekday A-E Mon-Fri; SIT fixed)
  String _formatDisplayVersion(String version) {
    return 'Ver $version SIT';
  }

  /// Tooltip: title "Latest Feature Release", then stripped commit message, then Released date.
  /// When commit/date are empty, shows version so tooltip is never blank.
  String _buildTooltip(VersionData data) {
    final buffer = StringBuffer();

    buffer.writeln('Latest Feature Release');
    buffer.writeln();

    if (data.lastFeatureCommit.isNotEmpty) {
      buffer.writeln(_displayCommitMessage(data.lastFeatureCommit));
      buffer.writeln();
    }

    if (data.featureDate.isNotEmpty) {
      buffer.writeln('Released:');
      buffer.writeln(data.featureDate);
    }

    if (data.lastFeatureCommit.isEmpty && data.featureDate.isEmpty) {
      buffer.writeln('Version: ${data.version}');
    }

    return buffer.toString();
  }

  /// Removes "Feature - ", "Feature: ", "feature: " etc. and optional "bug " so e.g.
  /// "Feature - bug Fix on the seetings screen" -> "Fix on the seetings screen".
  static String _displayCommitMessage(String raw) {
    String s = raw.trim();
    final featurePrefix = RegExp(r'^Feature\s*[-:]\s*', caseSensitive: false);
    s = s.replaceFirst(featurePrefix, '').trim();
    const bugPrefix = 'bug ';
    if (s.toLowerCase().startsWith(bugPrefix)) {
      s = s.substring(bugPrefix.length).trim();
    }
    return s.isEmpty ? raw : s;
  }

  void _onHover(bool isHovering) {
    if (isHovering) {
      _onSeenByUser();
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  Widget _buildVersionChild() {
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;
    final Color effectiveVersionColor = isLightMode
        ? Colors.black
        : (_colorAnimation.value ?? widget.textColor);

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Tooltip(
        message: _tooltipMessage,
        textAlign: TextAlign.center,
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
                  color: effectiveVersionColor,
                  fontWeight: FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;
    if (!_showAttentionCatcher) {
      return _buildVersionChild();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _pulseAnimation.value,
              child: Text(
                "See what's new — hover here.",
                style: TextStyle(
                  fontSize: 11,
                  color: isLightMode ? Colors.black : widget.textColor,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        _buildVersionChild(),
      ],
    );
  }
}
