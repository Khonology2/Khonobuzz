import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/managed_user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../services/sound_system.dart';
import '../theme/app_backgrounds.dart';
import '../providers/theme_mode_provider.dart';
import '../theme/app_text_colors.dart';
import '../theme/app_themes.dart';

enum OnboardingAlertStage { pendingApproval, assignmentsNeeded }

class OnboardingAlertPanel extends StatefulWidget {
  final List<ManagedUser> pendingUsers;
  final List<ManagedUser> activeUsersWithoutAssignments;
  final VoidCallback onClose;

  const OnboardingAlertPanel({
    super.key,
    required this.pendingUsers,
    required this.activeUsersWithoutAssignments,
    required this.onClose,
  });

  @override
  State<OnboardingAlertPanel> createState() => _OnboardingAlertPanelState();
}

class _OnboardingAlertPanelState extends State<OnboardingAlertPanel> {
  String? _processingUserId;

  OnboardingAlertStage? get _stage {
    if (widget.pendingUsers.isNotEmpty) {
      return OnboardingAlertStage.pendingApproval;
    }
    if (widget.activeUsersWithoutAssignments.isNotEmpty) {
      return OnboardingAlertStage.assignmentsNeeded;
    }
    return null;
  }

  List<ManagedUser> get _displayUsers {
    final stage = _stage;
    if (stage == OnboardingAlertStage.pendingApproval) {
      return widget.pendingUsers;
    }
    if (stage == OnboardingAlertStage.assignmentsNeeded) {
      return widget.activeUsersWithoutAssignments;
    }
    return const [];
  }

  String _buildUserFullName(ManagedUser user) {
    final fullName = '${user.firstName} ${user.lastName}'.trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }
    return user.displayName;
  }

  Future<void> _approveUser(ManagedUser user) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _processingUserId = user.id;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    final adminEmail = authProvider.userEmail?.trim() ?? '';
    final isSpecialSession = authProvider.isSpecialSession;

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};

      if (isSpecialSession) {
        headers['X-Session-Type'] = 'special';
      }

      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(user.id)),
        headers: headers,
        body: jsonEncode({
          'status': 'Active',
          if (adminEmail.isNotEmpty && !isSpecialSession)
            'adminApproved': adminEmail,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to approve user ${user.id}: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) {
        return;
      }

      ManagedUser? updatedUser;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        final backendUser = decoded?['user'] as Map<String, dynamic>?;
        if (backendUser != null) {
          final parsed = ManagedUser.fromApi(backendUser);
          updatedUser = parsed.copyWith(
            firstName: parsed.firstName.isNotEmpty
                ? parsed.firstName
                : user.firstName,
            lastName: parsed.lastName.isNotEmpty
                ? parsed.lastName
                : user.lastName,
            email: parsed.email.isNotEmpty ? parsed.email : user.email,
            department: parsed.department.isNotEmpty
                ? parsed.department
                : user.department,
            designation: parsed.designation.isNotEmpty
                ? parsed.designation
                : user.designation,
            role: parsed.role.isNotEmpty ? parsed.role : user.role,
            status: parsed.status.isNotEmpty ? parsed.status : 'Active',
            entity: (parsed.entity ?? '').trim().isNotEmpty
                ? parsed.entity
                : user.entity,
            manager: (parsed.manager ?? '').trim().isNotEmpty
                ? parsed.manager
                : user.manager,
            moduleAccess: (parsed.moduleAccess ?? '').trim().isNotEmpty
                ? parsed.moduleAccess
                : user.moduleAccess,
            moduleRole: (parsed.moduleRole ?? '').trim().isNotEmpty
                ? parsed.moduleRole
                : user.moduleRole,
            moduleAccessRole: (parsed.moduleAccessRole ?? '').trim().isNotEmpty
                ? parsed.moduleAccessRole
                : user.moduleAccessRole,
            phoneNumber: (parsed.phoneNumber ?? '').trim().isNotEmpty
                ? parsed.phoneNumber
                : user.phoneNumber,
            profilePictureUrl: (parsed.profilePictureUrl ?? '').trim().isNotEmpty
                ? parsed.profilePictureUrl
                : user.profilePictureUrl,
            createdAt: parsed.createdAt ?? user.createdAt,
            updatedAt: parsed.updatedAt ?? DateTime.now(),
            lastSignInAt: parsed.lastSignInAt ?? user.lastSignInAt,
            loginCount: parsed.loginCount > 0 ? parsed.loginCount : user.loginCount,
          );
        }
      } catch (_) {
        updatedUser = null;
      }

      if (updatedUser != null) {
        userProvider.updateUser(updatedUser);
      } else {
        final users = userProvider.users;
        final index = users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          users[index].status = 'Active';
          userProvider.updateUser(users[index]);
        }
      }

      final fullName = _buildUserFullName(user);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'User approved for $fullName. Assign module access and entity next.',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: appTextColor(context),
            ),
          ),
          backgroundColor: AppThemes.light.primaryColor,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to approve user. Please try again.',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: appTextColor(context),
            ),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeModeProvider>();
    final stage = _stage;
    final users = _displayUsers;

    if (stage == null || users.isEmpty) {
      return const SizedBox.shrink();
    }

    final title = stage == OnboardingAlertStage.pendingApproval
        ? 'New user onboarded'
        : 'Assign module access and entity';

    return Container(
      width: 400,
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                appBackgroundAsset(context),
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white.withValues(alpha: 0.40)
                    : const Color(0xFF1A1A1A).withValues(alpha: 0.85),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            stage == OnboardingAlertStage.pendingApproval
                                ? Icons.person_add
                                : Icons.assignment,
                            color: appTextColor(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: TextStyle(
                              color: appTextColor(context),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              SoundSystem.playButtonClick();
                              widget.onClose();
                            },
                            icon: Icon(
                              Icons.close,
                              color: appTextColor(context)
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stage == OnboardingAlertStage.pendingApproval
                        ? 'Review and approve new onboarded users so they can access the app.'
                        : 'These users are active but still need module access and entity assignments.',
                    style: TextStyle(
                      color: appTextColor(context).withValues(alpha: 0.72),
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final fullName = _buildUserFullName(user);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  stage == OnboardingAlertStage.pendingApproval
                                  ? Colors.orangeAccent
                                  : AppThemes.light.primaryColor,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      fullName,
                                      style: TextStyle(
                                        color: appTextColor(context),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          stage ==
                                              OnboardingAlertStage
                                                  .pendingApproval
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      stage ==
                                              OnboardingAlertStage
                                                  .pendingApproval
                                          ? 'Inactive'
                                          : 'Active',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: appTextColor(context)
                                      .withValues(alpha: 0.72),
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.department,
                                      style: TextStyle(
                                        color: appTextColor(context)
                                            .withValues(alpha: 0.62),
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      user.designation,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: appTextColor(context)
                                            .withValues(alpha: 0.62),
                                        fontSize: 12,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (stage ==
                                  OnboardingAlertStage.pendingApproval) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: _processingUserId == user.id
                                        ? null
                                        : () {
                                            SoundSystem.playButtonClick();
                                            _approveUser(user);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppThemes.light.primaryColor,
                                      foregroundColor: appTextColor(context),
                                    ),
                                    child: _processingUserId == user.id
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    appTextColor(context),
                                                  ),
                                            ),
                                          )
                                        : const Text(
                                            'Approve',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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
}
