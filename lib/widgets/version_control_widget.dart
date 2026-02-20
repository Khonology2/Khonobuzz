import 'dart:async';
import 'package:flutter/material.dart';
import 'package:khonobuzz/services/commit_service.dart';

/// A version control widget that displays app version with hover animation.
/// Displays version information at bottom of screens with smooth hover effects.
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
  String _tooltipMessage = 'Loading commit data...';
  String _currentVersion = 'Ver. 2026.02.CD0.SIT';

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
        // Generate dynamic version: {YYYY}.{MM}.{week-letter}{day-letter}{commit-count}.SIT
        final now = DateTime.now();

        // Get current year
        final yearStr = now.year.toString();

        // Get current month (MM format)
        final monthStr = now.month.toString().padLeft(2, '0');

        // Calculate week of the month (A=1st week, B=2nd week, C=3rd week, etc.)
        // Find the first day of the month and determine which week it falls into
        final firstDayOfMonth = DateTime(now.year, now.month, 1);
        final firstDayWeekday = firstDayOfMonth.weekday; // 1=Monday, 7=Sunday

        // Calculate how many days to subtract to get to the previous Monday
        // If first day is Monday (1), offset = 0
        // If first day is Tuesday (2), offset = 1 (go back to Monday)
        // If first day is Sunday (7), offset = 6 (go back to Monday)
        final offsetToMonday = (firstDayWeekday - 1) % 7;
        final firstMondayOfMonth = firstDayOfMonth.subtract(
          Duration(days: offsetToMonday),
        );

        // Calculate which week of the month this date falls into
        final daysSinceFirstMonday = now.difference(firstMondayOfMonth).inDays;
        final weekOfMonth = (daysSinceFirstMonday / 7).floor() + 1;
        final weekLetter = String.fromCharCode(
          64 + weekOfMonth,
        ); // A=1, B=2, C=3, etc.

        // Get day of week (A=Monday, B=Tuesday, C=Wednesday, D=Thursday, etc.)
        final dayOfWeek = now.weekday; // 1=Monday, 7=Sunday
        final dayLetter = String.fromCharCode(
          64 + dayOfWeek,
        ); // A=1, B=2, C=3, D=4, etc.

        final dynamicVersion =
            'Ver. $yearStr.$monthStr.$weekLetter$dayLetter${commitData.totalCommits}.SIT';

        setState(() {
          _currentVersion = dynamicVersion;
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
    // Filter commits that start with 'Feature' (case sensitive as specified)
    final featureCommits = commitData.commits
        .where((commit) => commit.message.startsWith('Feature'))
        .toList();

    if (featureCommits.isEmpty) {
      return 'Daily Commits\n\nNo feature commits found for today';
    }

    // Group by author and get the latest commit for each author
    final latestCommitsByAuthor = <String, CommitInfo>{};
    for (final commit in featureCommits) {
      // Compare timestamps to get the latest commit per author
      final currentLatest = latestCommitsByAuthor[commit.author];
      if (currentLatest == null ||
          DateTime.parse(
            commit.timestamp,
          ).isAfter(DateTime.parse(currentLatest.timestamp))) {
        latestCommitsByAuthor[commit.author] = commit;
      }
    }

    // Convert to list and sort by timestamp (most recent first)
    final latestCommits = latestCommitsByAuthor.values.toList()
      ..sort(
        (a, b) =>
            DateTime.parse(b.timestamp).compareTo(DateTime.parse(a.timestamp)),
      );

    final commitsText = latestCommits
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
