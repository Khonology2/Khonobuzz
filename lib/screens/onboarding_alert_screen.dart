import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/managed_user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

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
    return user.name;
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
          updatedUser = ManagedUser.fromApi(backendUser);
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
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
          ),
          backgroundColor: const Color(0xFFC10D00),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to approve user. Please try again.',
            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
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
                'assets/images/nathi_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.85),
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
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stage == OnboardingAlertStage.pendingApproval
                        ? 'Review and approve new onboarded users so they can access the app.'
                        : 'These users are active but still need module access and entity assignments.',
                    style: const TextStyle(
                      color: Colors.white70,
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
                                  : const Color(0xFFC10D00),
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
                                      style: const TextStyle(
                                        color: Colors.white,
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
                                          ? 'Pending'
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
                                style: const TextStyle(
                                  color: Colors.white70,
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
                                      style: const TextStyle(
                                        color: Colors.white60,
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
                                      style: const TextStyle(
                                        color: Colors.white60,
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
                                        : () => _approveUser(user),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC10D00),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: _processingUserId == user.id
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
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
