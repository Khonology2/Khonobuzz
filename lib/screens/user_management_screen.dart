import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../utils/pdh_firebase.dart'
    show
        updatePDHUserPartial,
        updateSkillsHeatmapUserPartial,
        syncUserToPDH,
        syncUserToSkillsHeatmap;
import '../models/managed_user.dart';
import '../config/api_config.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String? _updatingUserId;
  Timer? _debounceTimer;
  String _searchQuery = '';

  String? expandedUserId;
  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = <String>{};

  String? _selectedStatus;
  String? _selectedDepartment;
  String? _selectedDesignation;
  final Map<String, String> _editedDepartments = {};
  final Map<String, String> _editedDesignations = {};

  Set<String> get _availableStatuses {
    final userProvider = Provider.of<UserProvider>(context);
    return userProvider.users.map((user) => user.status).toSet();
  }

  Set<String> get _availableDepartments {
    final userProvider = Provider.of<UserProvider>(context);
    return userProvider.users.map((user) => user.department).toSet();
  }

  Set<String> get _availableDesignations {
    final userProvider = Provider.of<UserProvider>(context);
    return userProvider.users.map((user) => user.designation).toSet();
  }

  final Map<String, Color> userStatusColors = {
    'Active': Colors.green.shade600,
    'Inactive': Colors.grey.shade600,
    'Pending': Colors.orange.shade500,
  };

  final Map<String, Color> userRoleColors = {
    'Staff': Colors.blue.shade600,
    'Manager': Colors.purple.shade600,
    'Admin': const Color(0xFFC10D00),
  };

  final Map<String, Color> userStatusCircleColors = {
    'Active': Colors.green.shade500,
    'Inactive': Colors.grey.shade500,
    'Pending': Colors.orange.shade500,
  };

  final List<String> userRoles = ['Staff', 'Manager', 'Admin'];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ManagedUser> get _filteredUsers {
    final userProvider = Provider.of<UserProvider>(context);
    List<ManagedUser> users = userProvider.users;
    final query = _searchQuery.toLowerCase();

    if (query.isNotEmpty) {
      users = users.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.department.toLowerCase().contains(query) ||
            user.designation.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedStatus != null) {
      users = users.where((user) => user.status == _selectedStatus).toList();
    }

    if (_selectedDepartment != null) {
      users = users
          .where((user) => user.department == _selectedDepartment)
          .toList();
    }

    if (_selectedDesignation != null) {
      users = users
          .where((user) => user.designation == _selectedDesignation)
          .toList();
    }

    return users;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
     _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    userProvider.fetchUsers();

    if (userProvider.hasCachedData) {
      userProvider.refreshUsersInBackground();
    }
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  Future<void> _updateUserRoleAndStatus(
    String userId,
    String newRole,
    String newStatus, {
    required String firstName,
    required String lastName,
    required String department,
    required String designation,
    String? entity,
  }) async {
    setState(() {
      _updatingUserId = userId;
    });

    final authProvider = context.read<AuthProvider>();
    final adminEmail = authProvider.userEmail?.trim() ?? '';
    final isSpecialSession = authProvider.isSpecialSession;

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (isSpecialSession) {
        headers['X-Session-Type'] = 'special';
      }

      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(userId)),
        headers: headers,
        body: jsonEncode({
          'role': newRole,
          'status': newStatus,
          'entity': entity,
          'department': department,
          'designation': designation,
          if (adminEmail.isNotEmpty && !isSpecialSession)
            'adminApproved': adminEmail,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update user $userId: ${response.statusCode} ${response.body}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User updated for $firstName $lastName.',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFFC10D00),
          ),
        );
      }

      final adminField = adminEmail.isNotEmpty
          ? {
              'admin': {'approved': adminEmail},
            }
          : null;

      try {
        await updatePDHUserPartial(
          userId,
          {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
          onboardingFields: {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('PDH sync failed for user update: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'User info updated, but failed to sync with PDH.',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      try {
        await updateSkillsHeatmapUserPartial(
          userId,
          {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
          onboardingFields: {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('Skills Heatmap sync failed for user update: $e');
      }

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
          final backendUser = decoded?['user'] as Map<String, dynamic>?;
          if (backendUser != null) {
            final updatedUser = ManagedUser.fromApi(backendUser);
            userProvider.updateUser(updatedUser);
            _editedDepartments.remove(userId);
            _editedDesignations.remove(userId);
          } else {
            final users = userProvider.users;
            final index = users.indexWhere((u) => u.id == userId);
            if (index != -1) {
              users[index].role = newRole;
              users[index].status = newStatus;
              if (entity != null) {
                users[index].entity = entity;
              }
              userProvider.updateUser(users[index]);
            }
          }
        } catch (_) {
          final users = userProvider.users;
          final index = users.indexWhere((u) => u.id == userId);
          if (index != -1) {
            users[index].role = newRole;
            users[index].status = newStatus;
            if (entity != null) {
              users[index].entity = entity;
            }
            userProvider.updateUser(users[index]);
          }
        }
      }
    } finally {
      setState(() {
        _updatingUserId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddUserDialog(context),
              backgroundColor: const Color(0xFFC10D00),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      bottomNavigationBar: _isSelectionMode && _selectedUserIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedUserIds.length} user(s) selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = false;
                              _selectedUserIds.clear();
                            });
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              final allIds =
                                  _filteredUsers.map((u) => u.id).toSet();
                              if (_selectedUserIds.length == allIds.length) {
                                _selectedUserIds.clear();
                                _isSelectionMode = false;
                              } else {
                                _selectedUserIds
                                  ..clear()
                                  ..addAll(allIds);
                                _isSelectionMode = _selectedUserIds.isNotEmpty;
                              }
                            });
                          },
                          child: const Text(
                            'Select all',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () => _showDeleteConfirmation(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll<Color>(Colors.white),
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
                        _buildHeader(),
                        const SizedBox(height: 16.0),
                        _buildFiltersAndSearch(),
                        const SizedBox(height: 16.0),
                        _buildUserList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          'Empowering Your Workforce Through Management.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14.0,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersAndSearch() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  hint: const Text(
                    'FILTER STATUS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  dropdownColor: const Color(0xFF2C3E50),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedStatus = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    ..._availableStatuses.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDepartment,
                  hint: const Text(
                    'FILTER DEPARTMENT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  dropdownColor: const Color(0xFF2C3E50),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDepartment = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Departments'),
                    ),
                    ..._availableDepartments.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDesignation,
                  hint: const Text(
                    'FILTER DESIGNATION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  dropdownColor: const Color(0xFF2C3E50),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDesignation = newValue;
                    });
                  },
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Designations'),
                    ),
                    ..._availableDesignations.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: const TextStyle(
              color: Colors.white54,
              fontFamily: 'Poppins',
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            ),
            filled: true,
            fillColor: const Color(0x801F2840),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
          ),
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.isLoading && userProvider.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFC10D00)),
            const SizedBox(height: 24.0),
            Text(
              'Please wait. We\'re loading all users...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      );
    }

    if (userProvider.users.isEmpty && !userProvider.isLoading) {
      return const Center(
        child: Text(
          'No onboarding users found.',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
      );
    }

    return Column(
      children: _filteredUsers.map((user) {
        final bool isExpanded = expandedUserId == user.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            children: [
              _buildUserRow(user, isExpanded),
              if (isExpanded) _buildDropdownContent(user),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserRow(ManagedUser user, bool isExpanded) {
    final isSelected = _selectedUserIds.contains(user.id);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedUserIds.add(user.id);
            expandedUserId = null;
          });
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedUserIds.remove(user.id);
              if (_selectedUserIds.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              _selectedUserIds.add(user.id);
            }
          });
        } else {
          setState(() {
            expandedUserId = isExpanded ? null : user.id;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x80C10D00) : const Color(0x801F2840),
          borderRadius: BorderRadius.circular(16.0),
          border: isSelected
              ? Border.all(color: const Color(0xFFC10D00), width: 2.0)
              : null,
        ),
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final checkboxWidth = _isSelectionMode ? 48.0 : 0.0;
            final spacingWidth = 8.0 * 2;
            final columnWidth =
                ((availableWidth - checkboxWidth) - spacingWidth) / 3;
            final leftPadding = columnWidth * 0.12;

            final secondColumnWidth = columnWidth - leftPadding;

            return Row(
              children: [
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedUserIds.add(user.id);
                        } else {
                          _selectedUserIds.remove(user.id);
                          if (_selectedUserIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        }
                      });
                    },
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                  ),
                  const SizedBox(width: 8.0),
                ],

                SizedBox(
                  width: columnWidth,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 40.0,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 12.0),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                fontFamily: 'Poppins',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.0,
                                fontFamily: 'Poppins',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),

                Padding(
                  padding: EdgeInsets.only(left: leftPadding),
                  child: SizedBox(
                    width: secondColumnWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.designation,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.0,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          user.department,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.0,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),

                SizedBox(
                  width: columnWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (user.role.toLowerCase() != 'user') ...[
                        Flexible(child: _buildRoleBadge(user.role)),
                        const SizedBox(width: 8.0),
                      ],
                      Flexible(child: _buildStatusBadge(user.status)),
                      if (!_isSelectionMode) ...[
                        const SizedBox(width: 8.0),
                        Transform.rotate(
                          angle: isExpanded ? 3.14 : 0,
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: userRoleColors[role],
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: userStatusColors[status],
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildDropdownContent(ManagedUser user) {
    String selectedRole = user.role;
    String selectedStatusLocal = user.status;
    String selectedDepartmentLocal =
        _editedDepartments[user.id] ?? user.department;
    String selectedDesignationLocal =
        _editedDesignations[user.id] ?? user.designation;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0x801A1A1A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Role: ',
                      style: TextStyle(
                        color: Colors.white60,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value: userRoles.contains(selectedRole)
                            ? selectedRole
                            : null,
                        hint: const Text(
                          'Select role',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: const Color(0xFF2C3E50),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white70,
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedRole = newValue!;
                            user.role = newValue;
                          });
                        },
                        items: userRoles.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Status: ',
                      style: TextStyle(
                        color: Colors.white60,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value:
                            ['Active', 'Pending'].contains(selectedStatusLocal)
                            ? selectedStatusLocal
                            : null,
                        hint: const Text(
                          'Select status',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: const Color(0xFF2C3E50),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white70,
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedStatusLocal = newValue!;
                            user.status = newValue;
                          });
                        },
                        items: ['Active', 'Pending']
                            .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Department: ',
                      style: TextStyle(
                        color: Colors.white60,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value: selectedDepartmentLocal.isNotEmpty
                            ? selectedDepartmentLocal
                            : null,
                        hint: const Text(
                          'Select department',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: const Color(0xFF2C3E50),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white70,
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedDepartmentLocal = newValue ?? '';
                            if (selectedDepartmentLocal.isNotEmpty) {
                              _editedDepartments[user.id] =
                                  selectedDepartmentLocal;
                            } else {
                              _editedDepartments.remove(user.id);
                            }
                          });
                        },
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'Management',
                            child: Text('Management'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Operations',
                            child: Text('Operations'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Finance',
                            child: Text('Finance'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'HR',
                            child: Text('HR'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Sales',
                            child: Text('Sales'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Designation: ',
                      style: TextStyle(
                        color: Colors.white60,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value: selectedDesignationLocal.isNotEmpty
                            ? selectedDesignationLocal
                            : null,
                        hint: const Text(
                          'Select designation',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: const Color(0xFF2C3E50),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white70,
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedDesignationLocal = newValue ?? '';
                            if (selectedDesignationLocal.isNotEmpty) {
                              _editedDesignations[user.id] =
                                  selectedDesignationLocal;
                            } else {
                              _editedDesignations.remove(user.id);
                            }
                          });
                        },
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'Director',
                            child: Text('Director'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Developer',
                            child: Text('Developer'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Support Analyst',
                            child: Text('Support Analyst'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Learner',
                            child: Text('Learner'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'UX Designer',
                            child: Text('UX Designer'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'AWS Cloud Engineer',
                            child: Text('AWS Cloud Engineer'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Tester',
                            child: Text('Tester'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'RMB Small Talk Developer',
                            child: Text('RMB Small Talk Developer'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Finance',
                            child: Text('Finance'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Business Analyst',
                            child: Text('Business Analyst'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Manager',
                            child: Text('Manager'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Delivery Manager',
                            child: Text('Delivery Manager'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Analyst',
                            child: Text('Analyst'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Sales Person',
                            child: Text('Sales Person'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'HR',
                            child: Text('HR'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Junior Analyst',
                            child: Text('Junior Analyst'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Managed by: ',
                      style: TextStyle(
                        color: Colors.white60,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    GestureDetector(
                      onTap: () {
                        _showManagedByDialog(user);
                      },
                      child: Container(
                        height: 40.0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                user.manager?.isNotEmpty == true
                                    ? user.manager!
                                    : 'Select manager',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 14.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _updatingUserId == user.id
                  ? null
                  : () {
                      _updateUserRoleAndStatus(
                        user.id,
                        user.role,
                        user.status,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        department: selectedDepartmentLocal,
                        designation: selectedDesignationLocal,
                        entity: user.entity,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(45.0),
                ),
              ),
              child: _updatingUserId == user.id
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserManager(
    ManagedUser user,
    ManagedUser manager,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final adminEmail = authProvider.userEmail?.trim() ?? '';
    final isSpecialSession = authProvider.isSpecialSession;

    final managerFullName = '${manager.firstName} ${manager.lastName}'.trim().isNotEmpty
        ? '${manager.firstName} ${manager.lastName}'.trim()
        : manager.name;

    setState(() {
      _updatingUserId = user.id;
      user.manager = managerFullName;
    });

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (isSpecialSession) {
        headers['X-Session-Type'] = 'special';
      }

      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(user.id)),
        headers: headers,
        body: jsonEncode({
          'manager': managerFullName,
          if (adminEmail.isNotEmpty && !isSpecialSession)
            'adminApproved': adminEmail,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update manager for ${user.id}: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) return;

      try {
        await updatePDHUserPartial(
          user.id,
          {
            'manager': managerFullName,
          },
          onboardingFields: {
            'manager': managerFullName,
          },
        );
      } catch (e) {
        debugPrint('PDH manager sync failed: $e');
      }

      try {
        await updateSkillsHeatmapUserPartial(
          user.id,
          {
            'manager': managerFullName,
          },
          onboardingFields: {
            'manager': managerFullName,
          },
        );
      } catch (e) {
        debugPrint('Skills Heatmap manager sync failed: $e');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final backendUser = decoded?['user'] as Map<String, dynamic>?;
      if (backendUser != null && mounted) {
        final updatedUser = ManagedUser.fromApi(backendUser);
        final userProvider =
            Provider.of<UserProvider>(context, listen: false);
        userProvider.updateUser(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Manager set to $managerFullName for ${user.name}.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserId = null;
        });
      }
    }
  }

  void _showManagedByDialog(ManagedUser user) {
    final userProvider = context.read<UserProvider>();
    final allUsers = userProvider.users;

    final TextEditingController searchController = TextEditingController();
    ManagedUser? selectedManager;
    String query = '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final lowerQuery = query.toLowerCase().trim();
            final filtered = allUsers.where((candidate) {
              if (candidate.id == user.id) {
                return false;
              }

              if (candidate.department == 'Operations' &&
                  candidate.designation == 'Learner') {
                return false;
              }

              if (lowerQuery.isEmpty) {
                return true;
              }

              final name = candidate.name.toLowerCase();
              final email = candidate.email.toLowerCase();
              return name.contains(lowerQuery) || email.contains(lowerQuery);
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF2C3E50),
              title: Text(
                'Managed by: ${user.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Search manager',
                          labelStyle: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Poppins',
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFC10D00)),
                          ),
                        ),
                        onChanged: (value) {
                          setStateDialog(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12.0),
                      SizedBox(
                        height: 260,
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No users match your search.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final candidate = filtered[index];
                                  final isSelected =
                                      selectedManager?.id == candidate.id;
                                  return ListTile(
                                    title: Text(
                                      candidate.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    subtitle: Text(
                                      candidate.email,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontFamily: 'Poppins',
                                        fontSize: 12.0,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Color(0xFFC10D00),
                                          )
                                        : null,
                                    onTap: () {
                                      setStateDialog(() {
                                        selectedManager = candidate;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedManager == null
                      ? null
                      : () async {
                          final manager = selectedManager!;
                          Navigator.of(dialogContext).pop();
                          await _updateUserManager(user, manager);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontFamily: 'Poppins'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final TextEditingController emailsController = TextEditingController();
    bool isCreating = false;
    String? progressMessage;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C3E50),
              title: const Text(
                'Add New Users',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste emails (one per line or with "email:" prefix)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    const Text(
                      'Example:\nemail: nathi.radebez@khonology.com\nemail: john.doe@khonology.com',
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: emailsController,
                      maxLines: 10,
                      minLines: 5,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Emails',
                        labelStyle: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Poppins',
                        ),
                        hintText:
                            'email: user.name@khonology.com\nemail: another.user@khonology.com',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Poppins',
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(
                            color: Color(0xFFC10D00),
                          ),
                        ),
                      ),
                    ),
                    if (progressMessage != null) ...[
                      const SizedBox(height: 16.0),
                      Text(
                        progressMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          final emailsText = emailsController.text.trim();

                          if (emailsText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please paste at least one email',
                                  style: TextStyle(fontFamily: 'Poppins'),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final emails = _parseEmails(emailsText);

                          if (emails.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No valid emails found. Please check the format.',
                                  style: TextStyle(fontFamily: 'Poppins'),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isCreating = true;
                            progressMessage =
                                'Creating ${emails.length} user(s)...';
                          });

                          try {
                            final result = await _createMultipleUsers(emails, (
                              message,
                            ) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  progressMessage = message;
                                });
                              }
                            });

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              _showCreationSummary(context, result);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error creating users: ${e.toString()}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isCreating = false;
                                progressMessage = null;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Create Users',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _parseEmails(String text) {
    final List<String> emails = [];
    final lines = text.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.toLowerCase().startsWith('email:')) {
        final email = line.substring(6).trim();
        if (email.isNotEmpty && email.contains('@')) {
          emails.add(email);
        }
      } else if (line.contains('@')) {
        emails.add(line);
      }
    }

    return emails;
  }

  String _extractNameFromEmail(String email) {
    final emailParts = email.split('@');
    if (emailParts.isEmpty) return email;

    final localPart = emailParts[0];

    final nameParts = localPart.split('.');
    final capitalizedParts = nameParts.map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).toList();

    return capitalizedParts.join(' ');
  }

  bool _userExists(String email) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.users.any(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
  }

  Future<Map<String, dynamic>> _createMultipleUsers(
    List<String> emails,
    Function(String) onProgress,
  ) async {
    int successCount = 0;
    int failureCount = 0;
    int skippedCount = 0;
    final List<String> successEmails = [];
    final List<String> failureEmails = [];
    final List<String> skippedEmails = [];
    final List<String> errorMessages = [];

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.users.isEmpty) {
      onProgress('Loading existing users...');
      await userProvider.fetchUsers();
    }

    final validEmails = <String>[];
    for (final email in emails) {
      final trimmedEmail = email.trim();
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        failureCount++;
        failureEmails.add(trimmedEmail.isEmpty ? email : trimmedEmail);
        errorMessages.add('Invalid email format');
      } else if (_userExists(trimmedEmail)) {
        skippedCount++;
        skippedEmails.add(trimmedEmail);
      } else {
        validEmails.add(trimmedEmail);
      }
    }

    if (validEmails.isEmpty) {
      return {
        'successCount': 0,
        'failureCount': failureCount,
        'skippedCount': skippedCount,
        'successEmails': [],
        'failureEmails': failureEmails,
        'skippedEmails': skippedEmails,
        'errorMessages': errorMessages,
      };
    }

    const int batchSize = 10;
    int processedCount = 0;
    final totalEmails = validEmails.length;

    for (int i = 0; i < validEmails.length; i += batchSize) {
      final batch = validEmails.skip(i).take(batchSize).toList();
      final batchNumber = (i ~/ batchSize) + 1;
      final totalBatches = (validEmails.length / batchSize).ceil();

      onProgress(
        'Processing batch $batchNumber of $totalBatches (${processedCount + batch.length}/$totalEmails users)...',
      );

      final results = await Future.wait(
        batch.map((email) async {
          try {
            final fullName = _extractNameFromEmail(email);
            await _createNewUser(fullName, email, skipRefresh: true);
            return {'success': true, 'email': email, 'error': null};
          } catch (e) {
            debugPrint('Failed to create user $email: $e');
            return {'success': false, 'email': email, 'error': e.toString()};
          }
        }),
        eagerError: false,
      );

      for (final result in results) {
        if (result['success'] as bool) {
          successCount++;
          successEmails.add(result['email'] as String);
        } else {
          failureCount++;
          failureEmails.add(result['email'] as String);
          errorMessages.add(result['error'] as String? ?? 'Unknown error');
        }
        processedCount++;
      }

      onProgress(
        'Progress: $processedCount/$totalEmails users processed ($successCount created, $failureCount failed, $skippedCount skipped)',
      );

      if (i + batchSize < validEmails.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (successCount > 0) {
      onProgress('Refreshing user list...');

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchUsers();
      }
    }

    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'skippedCount': skippedCount,
      'successEmails': successEmails,
      'failureEmails': failureEmails,
      'skippedEmails': skippedEmails,
      'errorMessages': errorMessages,
    };
  }

  void _showCreationSummary(BuildContext context, Map<String, dynamic> result) {
    final successCount = result['successCount'] as int;
    final failureCount = result['failureCount'] as int;
    final skippedCount = result['skippedCount'] as int;
    final successEmails = result['successEmails'] as List<String>;
    final failureEmails = result['failureEmails'] as List<String>;
    final skippedEmails = result['skippedEmails'] as List<String>;
    final errorMessages = result['errorMessages'] as List<String>;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: Text(
            'Creation Summary',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully created: $successCount user(s)',
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (skippedCount > 0) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    'Skipped (already exists): $skippedCount user(s)',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (failureCount > 0) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    'Failed: $failureCount user(s)',
                    style: const TextStyle(
                      color: Colors.red,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (successEmails.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  const Text(
                    'Successfully created:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  ...successEmails
                      .take(10)
                      .map(
                        (email) => Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                          child: Text(
                            '• $email',
                            style: const TextStyle(
                              color: Colors.green,
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                            ),
                          ),
                        ),
                      ),
                  if (successEmails.length > 10)
                    Text(
                      '... and ${successEmails.length - 10} more',
                      style: const TextStyle(
                        color: Colors.green,
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
                if (failureEmails.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  const Text(
                    'Failed:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  ...failureEmails.asMap().entries.take(10).map((entry) {
                    final index = entry.key;
                    final email = entry.value;
                    final errorMsg = index < errorMessages.length
                        ? errorMessages[index]
                        : 'Unknown error';
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• $email',
                            style: const TextStyle(
                              color: Colors.red,
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                            ),
                          ),
                          if (errorMsg.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                                top: 2.0,
                              ),
                              child: Text(
                                errorMsg.length > 50
                                    ? '${errorMsg.substring(0, 50)}...'
                                    : errorMsg,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: 'Poppins',
                                  fontSize: 10.0,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (failureEmails.length > 10)
                    Text(
                      '... and ${failureEmails.length - 10} more',
                      style: const TextStyle(
                        color: Colors.red,
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
                if (skippedEmails.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  const Text(
                    'Skipped (already exists):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  ...skippedEmails.take(10).map((email) {
                    final name = _extractNameFromEmail(email);
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• $email',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                            child: Text(
                              '($name)',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontFamily: 'Poppins',
                                fontSize: 10.0,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (skippedEmails.length > 10)
                    Text(
                      '... and ${skippedEmails.length - 10} more',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewUser(
    String fullName,
    String email, {
    bool skipRefresh = false,
  }) async {
    final nameParts = fullName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final adminEmail = context.read<AuthProvider>().userEmail?.trim() ?? '';

    try {
      final registerResponse = await http.post(
        Uri.parse(ApiConfig.authRegisterEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': 'password',
          'name': fullName,
          'firstName': firstName,
          'lastName': lastName,
          'role': 'Staff',
          'department': '',
          'designation': '',
        }),
      );

      if (registerResponse.statusCode != 201) {
        final errorBody = registerResponse.body;
        throw Exception(
          'Failed to create user: ${registerResponse.statusCode} - $errorBody',
        );
      }

      final responseData = json.decode(registerResponse.body);
      final userPayload = responseData['user'] as Map<String, dynamic>? ?? {};
      final String uid = userPayload['id'] ?? '';

      if (uid.isEmpty) {
        throw Exception('User created but no ID returned');
      }

      final Map<String, dynamic> userData = {
        'email': email,
        'password': 'password',
        'name': fullName,
        'role': 'Staff',
        'status': 'Pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'entity': '',
        'department': '',
        'designation': '',
        if (adminEmail.isNotEmpty) 'admin': {'approved': adminEmail},
      };

      final Map<String, dynamic> onboardingData = {
        'user_id': uid,
        'email': email,
        'name': firstName,
        'surname': lastName,
        'fullName': fullName.trim(),
        'department': '',
        'designation': '',
        'status': 'Pending',
        'role': 'Staff',
        'first_valid': DateTime.utc(2025, 9, 25).toIso8601String(),
        'inserted_by': adminEmail.isNotEmpty ? adminEmail : email,
        'last_valid': DateTime.utc(2039, 12, 31).toIso8601String(),
        'onboarding_id': uid,
        'status_id': '',
        if (adminEmail.isNotEmpty) 'admin': {'approved': adminEmail},
      };

      try {
        await syncUserToPDH(userData, onboardingData, uid);
      } catch (e) {
        debugPrint('PDH sync failed for new user: $e');
      }

      try {
        await syncUserToSkillsHeatmap(userData, onboardingData, uid);
      } catch (e) {
        debugPrint('Skills Heatmap sync failed for new user: $e');
      }

      if (!skipRefresh && mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchUsers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User $fullName created successfully!',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFFC10D00),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating new user: $e');
      rethrow;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final selectedCount = _selectedUserIds.length;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: const Text(
            'Delete Users',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete $selectedCount user(s)?',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteUsers(_selectedUserIds.toList());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUsers(List<String> userIds) async {
    if (userIds.isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    setState(() {
      _isSelectionMode = false;
      if (expandedUserId != null && userIds.contains(expandedUserId)) {
        expandedUserId = null;
      }
      _selectedUserIds.clear();
    });

    userProvider.removeUsers(userIds);

    int failureCount = 0;
    final List<String> failedUserIds = [];
    final List<String> errorMessages = [];

    const int batchSize = 10;
    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();

      final results = await Future.wait(
        batch.map((userId) async {
          try {
            await _deleteUser(userId);
            return {'success': true, 'userId': userId, 'error': null};
          } catch (e) {
            debugPrint('Failed to delete user $userId: $e');
            return {'success': false, 'userId': userId, 'error': e.toString()};
          }
        }),
        eagerError: false,
      );

      for (final result in results) {
        if (!(result['success'] as bool)) {
          failureCount++;
          failedUserIds.add(result['userId'] as String);
          errorMessages.add(result['error'] as String? ?? 'Unknown error');
        }
      }

      if (i + batchSize < userIds.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (failureCount > 0 && failedUserIds.isNotEmpty && errorMessages.isNotEmpty) {
      debugPrint(
        'Failed to delete $failureCount user(s): ${failedUserIds.join(', ')}. '
        'Errors: ${errorMessages.join(' | ')}',
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.deleteUserEndpoint(userId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorBody = response.body;
        throw Exception(
          'Failed to delete user: ${response.statusCode} - $errorBody',
        );
      }

      debugPrint('Successfully deleted user $userId');
    } catch (e) {
      debugPrint('Error deleting user $userId: $e');
      rethrow;
    }
  }
}
