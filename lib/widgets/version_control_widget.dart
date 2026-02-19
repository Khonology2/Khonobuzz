import 'dart:async';
import 'package:flutter/material.dart';
import 'package:khonobuzz/services/commit_service.dart';

/// A version control widget that displays app version with hover animation.
/// Displays version information at bottom of screens with smooth hover effects.
class VersionControlWidget extends StatefulWidget {
  const VersionControlWidget({
    super.key,
    this.version = 'Ver. 2026.02.CD1.0.SIT',
    this.fontSize = 12.0,
    this.textColor = Colors.white70,
    this.hoverColor = Colors.white,
  });

  final String version;
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
  String _tooltipMessage = 'Loading commit data...';

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

    // Start auto-refresh timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadCommitData();
    });

    _loadCommitData();
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
      _loadCommitData(); // Refresh when app resumes
    }
  }

  Future<void> _loadCommitData() async {
    try {
      final commitData = await CommitService.loadCommitData();

      if (mounted) {
        setState(() {
          _tooltipMessage = _generateTooltipMessage(commitData);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tooltipMessage = 'Failed to load commit data';
        });
      }
    }
  }

  String _generateTooltipMessage(CommitData commitData) {
    if (commitData.commits.isEmpty) {
      return 'Daily Commits\n\nNo commits found for today';
    }

    final commitsText = commitData.commits
        .map((commit) {
          return '${commit.author} - ${commit.message}';
        })
        .join('\n');

    return 'Daily Commits\n\n$commitsText';
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
                widget.version,
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
