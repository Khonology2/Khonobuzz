// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/admin_alert.dart';
import '../providers/admin_alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/admin_alert_service.dart';
import '../theme/app_backgrounds.dart';
import '../theme/app_text_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _accent = Color(0xFFC10D00);
  static final Color _darkWidgetBg = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.10),
    const Color(0xFF3D3F40).withValues(alpha: 0.40),
  );

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatAlertTimestamp(DateTime timestamp) {
    return DateFormat('EEE, dd MMM yyyy • hh:mm a').format(timestamp.toLocal());
  }

  bool _isAdminRole(String role) => role.trim().toLowerCase() == 'admin';

  Future<void> _showAnnouncementDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool requiresAck = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            final bool isDark = Theme.of(dialogContext).brightness == Brightness.dark;
            final Color dialogBg = isDark
                ? _darkWidgetBg
                : Colors.white.withValues(alpha: 0.45);
            final Color textColor = appTextColor(dialogContext);

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: textColor.withValues(alpha: isDark ? 0.18 : 0.12),
                ),
              ),
              title: Text(
                'Send announcement',
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: textColor, fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: textColor.withValues(alpha: 0.18),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      style: TextStyle(color: textColor, fontFamily: 'Poppins'),
                      decoration: InputDecoration(
                        labelText: 'Message',
                        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: textColor.withValues(alpha: 0.18),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: requiresAck,
                      onChanged: (v) => setStateDialog(() => requiresAck = v),
                      title: Text(
                        'Require acknowledgment',
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: textColor, fontFamily: 'Poppins'),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    final actor = (authProvider.userEmail ?? '').trim();
                    final title = titleController.text.trim();
                    final message = messageController.text.trim();
                    if (actor.isEmpty || title.isEmpty || message.isEmpty) {
                      Navigator.of(ctx).pop(false);
                      return;
                    }

                    await AdminAlertService.publishAdminChange(
                      actorEmail: actor,
                      title: title,
                      message: message,
                      area: 'announcement',
                      targetRoles: const ['staff', 'admin'],
                      requiresAck: requiresAck,
                      effectiveDateIso: DateTime.now().toUtc().toIso8601String(),
                    );
                    Navigator.of(ctx).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      await context.read<AdminAlertProvider>().start(
        context.read<AuthProvider>().userRole ?? '',
        userEmail: context.read<AuthProvider>().userEmail ?? '',
      );
    }
  }

  Future<void> _clearAllAlerts() async {
    final alertsProvider = context.read<AdminAlertProvider>();
    await alertsProvider.clearAllAlerts();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'All alerts cleared.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: _accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertsProvider = context.watch<AdminAlertProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();

    final role = (authProvider.userRole ?? 'staff').trim().toLowerCase();
    final bool isAdmin = _isAdminRole(role);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark
        ? _darkWidgetBg
        : Colors.white.withValues(alpha: 0.42);
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.12);

    final alerts = alertsProvider.alerts;
    final pendingAckCount = alerts
        .where((alert) => alert.requiresAck && !alert.acknowledged)
        .length;

    final pendingUsers = userProvider.users
        .where((u) => u.status == 'Inactive')
        .toList();
    final unassignedUsers = userProvider.users
        .where(
          (u) =>
              u.status.toLowerCase() == 'active' &&
              ((u.entity ?? '').trim().isEmpty ||
                  (u.moduleAccess ?? '').trim().isEmpty),
        )
        .toList();
    final adminSystemAlerts = <String>[
      if (pendingUsers.isNotEmpty)
        '${pendingUsers.length} new enrolled user(s) pending review.',
      if (unassignedUsers.isNotEmpty)
        '${unassignedUsers.length} active user(s) missing entity or module assignment.',
    ];

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
                thumbColor: WidgetStatePropertyAll<Color>(appTextColor(context)),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(
                          role: role,
                          isAdmin: isAdmin,
                          alertsCount: alerts.length,
                          pendingAckCount: pendingAckCount,
                          systemAlertCount: adminSystemAlerts.length,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildStatCard(
                              context: context,
                              label: 'Total alerts',
                              value: '${alerts.length}',
                              icon: Icons.notifications_active_outlined,
                              accent: _accent,
                              surface: surface,
                              borderColor: borderColor,
                            ),
                            _buildStatCard(
                              context: context,
                              label: 'Needs attention',
                              value: '$pendingAckCount',
                              icon: Icons.priority_high_rounded,
                              accent: Colors.orange,
                              surface: surface,
                              borderColor: borderColor,
                            ),
                            if (isAdmin)
                              _buildStatCard(
                                context: context,
                                label: 'System notices',
                                value: '${adminSystemAlerts.length}',
                                icon: Icons.admin_panel_settings_outlined,
                                accent: Colors.blueGrey,
                                surface: surface,
                                borderColor: borderColor,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isAdmin && adminSystemAlerts.isNotEmpty) ...[
                          _buildSectionHeader(
                            context: context,
                            title: 'Admin system notices',
                            subtitle:
                                'Operational reminders pulled from user records.',
                          ),
                          const SizedBox(height: 12),
                          ...adminSystemAlerts.map(
                            (text) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildSystemAlertCard(
                                context: context,
                                text: text,
                                surface: surface,
                                borderColor: borderColor,
                              ),
                            ),
                          ),
                        ],
                        _buildSectionHeader(
                          context: context,
                          title: isAdmin ? 'Admin notifications' : 'Staff notifications',
                          subtitle: isAdmin
                              ? 'Announcements and action items for admins.'
                              : 'Announcements and action items for your account.',
                        ),
                        const SizedBox(height: 12),
                        if (alerts.isEmpty && adminSystemAlerts.isEmpty)
                          _buildEmptyState(context, isAdmin: isAdmin, surface: surface)
                        else
                          Column(
                            children: alerts.isEmpty
                                ? const <Widget>[]
                                : alerts
                                    .map(
                                      (alert) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _buildAlertCard(
                                          context: context,
                                          alert: alert,
                                          role: role,
                                          surface: surface,
                                          borderColor: borderColor,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAnnouncementDialog,
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text(
                'Send announcement',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader({
    required String role,
    required bool isAdmin,
    required int alertsCount,
    required int pendingAckCount,
    required int systemAlertCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = appTextColor(context);
    final subtitleColor = textColor.withValues(alpha: isDark ? 0.78 : 0.72);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isAdmin
                    ? 'Monitor announcements, reminders, and user-related alerts.'
                    : 'Keep track of updates, approvals, and messages for your account.',
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Portal: ${role.toUpperCase()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: subtitleColor,
                  fontFamily: 'Poppins',
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _clearAllAlerts,
              icon: const Icon(Icons.clear_all),
              label: const Text(
                'Clear all',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: textColor.withValues(alpha: 0.35)),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: textColor.withValues(alpha: 0.12)),
              ),
              child: Text(
                isAdmin
                    ? '$alertsCount alerts • $pendingAckCount pending • $systemAlertCount system'
                    : '$alertsCount alerts • $pendingAckCount pending',
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required Color surface,
    required Color borderColor,
  }) {
    final textColor = appTextColor(context);
    return _HoverableSurface(
      childWidth: 220,
      borderRadius: BorderRadius.circular(16),
      baseShadowColor: Colors.black.withValues(alpha: 0.08),
      hoverShadowColor: accent.withValues(alpha: 0.18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.75),
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) {
    final textColor = appTextColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.72),
            fontFamily: 'Poppins',
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemAlertCard({
    required BuildContext context,
    required String text,
    required Color surface,
    required Color borderColor,
  }) {
    final textColor = appTextColor(context);
    return _HoverableSurface(
      borderRadius: BorderRadius.circular(16),
      baseShadowColor: Colors.black.withValues(alpha: 0.08),
      hoverShadowColor: _accent.withValues(alpha: 0.16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required bool isAdmin,
    required Color surface,
  }) {
    final textColor = appTextColor(context);
    return _HoverableSurface(
      borderRadius: BorderRadius.circular(18),
      baseShadowColor: Colors.black.withValues(alpha: 0.08),
      hoverShadowColor: _accent.withValues(alpha: 0.14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: textColor.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: _accent,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No alerts yet.',
              style: TextStyle(
                color: textColor,
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'Admin alerts and system notices will appear here when users need review or action.'
                  : 'You’ll see announcements and action items here when they are sent to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.72),
                fontFamily: 'Poppins',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required BuildContext context,
    required AdminAlert alert,
    required String role,
    required Color surface,
    required Color borderColor,
  }) {
    final bool isAdmin = _isAdminRole(role);
    final bool needsAck = alert.requiresAck && !alert.acknowledged;
    final bool highlight = needsAck || isAdmin;
    final textColor = appTextColor(context);
    final Color accentColor = needsAck ? Colors.orange : _accent;
    final Color chipBg = accentColor.withValues(alpha: 0.12);
    final String statusLabel = alert.requiresAck
        ? (alert.acknowledged ? 'Acknowledged' : 'Needs attention')
        : 'Info';

    return _HoverableSurface(
      borderRadius: BorderRadius.circular(18),
      baseShadowColor: Colors.black.withValues(alpha: highlight ? 0.12 : 0.08),
      hoverShadowColor: accentColor.withValues(alpha: 0.18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlight
                ? accentColor.withValues(alpha: 0.50)
                : borderColor,
            width: highlight ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    needsAck
                        ? Icons.priority_high_rounded
                        : Icons.notifications_active_outlined,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _buildStatusChip(
                            context: context,
                            label: statusLabel,
                            accent: accentColor,
                            surface: chipBg,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.message,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  context: context,
                  icon: Icons.category_outlined,
                  label: alert.area.isEmpty ? 'General' : alert.area,
                  surface: surface,
                  borderColor: borderColor,
                ),
                _buildInfoChip(
                  context: context,
                  icon: Icons.schedule_outlined,
                  label: _formatAlertTimestamp(alert.createdAt),
                  surface: surface,
                  borderColor: borderColor,
                ),
                _buildInfoChip(
                  context: context,
                  icon: Icons.person_outline,
                  label: alert.actorEmail.isEmpty ? 'KhonoBuzz' : alert.actorEmail,
                  surface: surface,
                  borderColor: borderColor,
                ),
                if (isAdmin && alert.requiresAck)
                  _buildInfoChip(
                    context: context,
                    icon: Icons.verified_outlined,
                    label: 'Ack ${alert.acknowledgedCount}/${alert.targetCount}',
                    surface: surface,
                    borderColor: borderColor,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!isAdmin && alert.requiresAck && !alert.acknowledged)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context
                          .read<AdminAlertProvider>()
                          .acknowledgeAlert(alert.id);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Acknowledge',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isAdmin && alert.requiresAck && !alert.acknowledged)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await context
                          .read<AdminAlertProvider>()
                          .acknowledgeAlert(alert.id);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Mark acknowledged',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await context.read<AdminAlertProvider>().dismissAlert(alert.id);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Dismiss',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                  style: TextButton.styleFrom(foregroundColor: textColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color surface,
    required Color borderColor,
  }) {
    final textColor = appTextColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor.withValues(alpha: 0.82)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required BuildContext context,
    required String label,
    required Color accent,
    required Color surface,
  }) {
    final textColor = appTextColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent == _accent ? textColor : accent,
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _HoverableSurface extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color baseShadowColor;
  final Color hoverShadowColor;
  final double childWidth;

  const _HoverableSurface({
    required this.child,
    required this.borderRadius,
    required this.baseShadowColor,
    required this.hoverShadowColor,
    this.childWidth = double.infinity,
  });

  @override
  State<_HoverableSurface> createState() => _HoverableSurfaceState();
}

class _HoverableSurfaceState extends State<_HoverableSurface> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          width: widget.childWidth,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: _isHovered ? widget.hoverShadowColor : widget.baseShadowColor,
                blurRadius: _isHovered ? 22 : 16,
                offset: Offset(0, _isHovered ? 10 : 6),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
