import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/managed_user.dart';
import 'admin_profile_screen_new.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _showOnboardingAlert = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.fetchUsers();

    final pendingUsers = userProvider.users
        .where((u) => u.status == 'Pending')
        .toList();
    final activeUsersWithoutAssignments = userProvider.users
        .where(
          (u) =>
              u.status == 'Active' &&
              ((u.moduleAccess?.isEmpty ?? true) ||
                  (u.entity?.isEmpty ?? true)),
        )
        .toList();

    if (pendingUsers.isNotEmpty || activeUsersWithoutAssignments.isNotEmpty) {
      setState(() {
        _showOnboardingAlert = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final authProvider = context.watch<AuthProvider>();

    final pendingUsers = userProvider.users
        .where((u) => u.status == 'Pending')
        .toList();
    final activeUsersWithoutAssignments = userProvider.users
        .where(
          (u) =>
              u.status == 'Active' &&
              ((u.moduleAccess?.isEmpty ?? true) ||
                  (u.entity?.isEmpty ?? true)),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Admin Profile',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use two-column layout for wider screens
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                // Left column - Admin profile and stats
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(authProvider),
                        const SizedBox(height: 24),
                        _buildStatsCards(
                          pendingUsers.length,
                          activeUsersWithoutAssignments.length,
                        ),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                      ],
                    ),
                  ),
                ),
                // Right column - Onboarding alerts and user management
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_showOnboardingAlert &&
                            (pendingUsers.isNotEmpty ||
                                activeUsersWithoutAssignments.isNotEmpty))
                          OnboardingAlertPanel(
                            pendingUsers: pendingUsers,
                            activeUsersWithoutAssignments:
                                activeUsersWithoutAssignments,
                            onClose: () {
                              setState(() {
                                _showOnboardingAlert = false;
                              });
                            },
                          ),
                        if (_showOnboardingAlert &&
                            (pendingUsers.isNotEmpty ||
                                activeUsersWithoutAssignments.isNotEmpty))
                          const SizedBox(height: 16),
                        Expanded(
                          child: _buildRecentUsers(
                            userProvider.users.take(10).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Single column layout for smaller screens
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(authProvider),
                  const SizedBox(height: 24),
                  _buildStatsCards(
                    pendingUsers.length,
                    activeUsersWithoutAssignments.length,
                  ),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  if (_showOnboardingAlert &&
                      (pendingUsers.isNotEmpty ||
                          activeUsersWithoutAssignments.isNotEmpty))
                    OnboardingAlertPanel(
                      pendingUsers: pendingUsers,
                      activeUsersWithoutAssignments:
                          activeUsersWithoutAssignments,
                      onClose: () {
                        setState(() {
                          _showOnboardingAlert = false;
                        });
                      },
                    ),
                  if (_showOnboardingAlert &&
                      (pendingUsers.isNotEmpty ||
                          activeUsersWithoutAssignments.isNotEmpty))
                    const SizedBox(height: 16),
                  _buildRecentUsers(userProvider.users.take(10).toList()),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildProfileHeader(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC10D00).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFC10D00),
                child: Text(
                  authProvider.userEmail?.substring(0, 2).toUpperCase() ?? 'AD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Administrator',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      authProvider.userEmail ?? 'admin@example.com',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(int pendingCount, int assignmentsCount) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                const Icon(Icons.person_add, color: Colors.orange, size: 24),
                const SizedBox(height: 8),
                Text(
                  '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Text(
                  'Pending Approval',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFC10D00).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFC10D00).withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.assignment,
                  color: Color(0xFFC10D00),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  '$assignmentsCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const Text(
                  'Need Assignments',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to user management
                },
                icon: const Icon(Icons.people, size: 18),
                label: const Text('Manage Users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to module access
                },
                icon: const Icon(Icons.security, size: 18),
                label: const Text('Module Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentUsers(List<ManagedUser> users) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Recent Users',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Colors.grey),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: user.status == 'Active'
                      ? Colors.green
                      : user.status == 'Pending'
                      ? Colors.orange
                      : Colors.grey,
                  child: Text(
                    user.firstName.isNotEmpty
                        ? user.firstName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  '${user.firstName} ${user.lastName}'.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
                subtitle: Text(
                  user.email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user.status == 'Active'
                        ? Colors.green.withOpacity(0.2)
                        : user.status == 'Pending'
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.status,
                    style: TextStyle(
                      color: user.status == 'Active'
                          ? Colors.green
                          : user.status == 'Pending'
                          ? Colors.orange
                          : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
