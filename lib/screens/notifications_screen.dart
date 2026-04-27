// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/admin_alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_backgrounds.dart';
import '../theme/app_text_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static final Color _notificationsDarkWidgetBg = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.10),
    const Color(0xFF3D3F40).withValues(alpha: 0.40),
  );

  String _formatAlertTimestamp(DateTime timestamp) {
    return DateFormat('EEE, dd MMM yyyy • hh:mm a').format(timestamp.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final alertsProvider = context.watch<AdminAlertProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final alerts = alertsProvider.alerts;
    final role = (authProvider.userRole ?? 'staff').trim().toLowerCase();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelBg = isDark
        ? _notificationsDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);
    final pendingUsers = userProvider.users
        .where((u) => u.status.toLowerCase() == 'pending')
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
        '${unassignedUsers.length} active user(s) missing entity/module assignment.',
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC10D00),
        foregroundColor: Colors.white,
        title: Text(
          'Notifications - ${role.toUpperCase()}',
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await alertsProvider.clearAllAlerts();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'All alerts cleared.',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                  backgroundColor: Color(0xFFC10D00),
                ),
              );
            },
            child: const Text(
              'Read all',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(appBackgroundAsset(context)),
            fit: BoxFit.cover,
          ),
        ),
        child: (alerts.isEmpty && !(role == 'admin' && adminSystemAlerts.isNotEmpty))
            ? Center(
                child: Text(
                  'No alerts yet.',
                  style: TextStyle(
                    color: appTextColor(context),
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: alerts.length + (role == 'admin' ? adminSystemAlerts.length : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (role == 'admin' && index < adminSystemAlerts.length) {
                    final text = adminSystemAlerts[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFC10D00).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  final alertIndex =
                      role == 'admin' ? index - adminSystemAlerts.length : index;
                  final alert = alerts[alertIndex];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: panelBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFC10D00).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          alert.message,
                          style: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatAlertTimestamp(alert.createdAt),
                          style: TextStyle(
                            color: appTextColor(context).withValues(alpha: 0.72),
                            fontFamily: 'Poppins',
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Area: ${alert.area}  |  By: ${alert.actorEmail}',
                          style: TextStyle(
                            color: appTextColor(context).withValues(alpha: 0.72),
                            fontFamily: 'Poppins',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
