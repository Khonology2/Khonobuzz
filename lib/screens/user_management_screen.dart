import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../utils/pdh_firebase.dart';
import '../models/managed_user.dart';
import '../config/api_config.dart';
import '../providers/user_provider.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String? _updatingUserId; // Track which user is being updated
  Timer? _debounceTimer;
  String _searchQuery = '';

  // Removed the static 'users' list as data will be fetched dynamically
  // final List<User> users = [
  //   User(id: '1', firstName: 'Name', lastName: 'Surname', email: 'name.surname@khonology.com', designation: 'Specialist Designation', role: 'Staff', status: 'Active'),
  //   User(id: '2', firstName: 'Name', lastName: 'Surname', email: 'name.surname@khonology.com', designation: 'Specialist Designation', role: 'Staff', status: 'Active'),
  //   User(id: '3', firstName: 'Name', lastName: 'Surname', email: 'name.surname@khonology.com', designation: 'Specialist Designation', role: 'Manager', status: 'Active'),
  //   User(id: '4', firstName: 'Name', lastName: 'Surname', email: 'name.surname@khonology.com', designation: 'Specialist Designation', role: 'Admin', status: 'Pending'),
  //   User(id: '5', firstName: 'Name', lastName: 'Surname', email: 'name.surname@khonology.com', designation: 'Specialist Designation', role: 'Staff', status: 'Inactive'),
  // ];

  String? expandedUserId;

  String? _selectedStatus;
  String? _selectedDepartment;
  String? _selectedDesignation;

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

  static const double _designationColumnWidth = 240.0;
  static const double _badgeAreaWidth = 200.0;

  final TextEditingController _searchController = TextEditingController();

  List<ManagedUser> get _filteredUsers {
    final userProvider = Provider.of<UserProvider>(context);
    List<ManagedUser> users = userProvider.users;
    final query = _searchQuery.toLowerCase();

    // Apply search query filter
    if (query.isNotEmpty) {
      users = users.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.department.toLowerCase().contains(query) ||
            user.designation.toLowerCase().contains(query);
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      users = users.where((user) => user.status == _selectedStatus).toList();
    }

    // Apply department filter
    if (_selectedDepartment != null) {
      users = users
          .where((user) => user.department == _selectedDepartment)
          .toList();
    }

    // Apply designation filter
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // Fetch users if not cached or cache expired
    userProvider.fetchUsers();
    // Refresh in background if cache exists
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

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(userId)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': newRole,
          'status': newStatus,
          'entity': entity,
        }),
      );

      debugPrint(
        'Update user response: ${response.statusCode} ${response.body}',
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

      try {
        // Sync with PDH
        await updatePDHUserPartial(
          userId,
          {'role': newRole, 'status': newStatus, 'entity': entity},
          onboardingFields: {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
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

      // Update local state with backend response
      // ignore: use_build_context_synchronously
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        final backendUser = decoded?['user'] as Map<String, dynamic>?;
        if (backendUser != null) {
          // Update the user in the provider cache
          final updatedUser = ManagedUser.fromApi(backendUser);
          userProvider.updateUser(updatedUser);
        } else {
          // Update user in provider cache directly
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
        // Update user in provider cache directly if parsing fails
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
    } catch (e) {
      // Optionally show error to user
    } finally {
      setState(() {
        _updatingUserId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
              fit: BoxFit.cover,
            ),
          ),
          // Existing content
          Positioned.fill(
            child: SingleChildScrollView(
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
    return InkWell(
      onTap: () {
        setState(() {
          expandedUserId = isExpanded ? null : user.id;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x801F2840),
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.person, size: 40.0, color: Colors.white54),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12.0,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            SizedBox(
              width:
                  _designationColumnWidth, // Fixed width for consistent alignment
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.designation, // Displaying designation as requested for the second line
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    user.department, // Displaying department as requested for the second line
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12.0,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: _badgeAreaWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (user.role.toLowerCase() != 'user') ...[
                    _buildRoleBadge(user.role),
                    const SizedBox(width: 8.0),
                  ],
                  _buildStatusBadge(user.status),
                  const SizedBox(width: 8.0),
                  Transform.rotate(
                    angle: isExpanded ? 3.14 : 0,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
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
    String selectedStatusLocal = user.status; // Local state for status
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        // ignore: use_full_hex_values_for_flutter_colors
        color: Color(0x801a1a1a1a),
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
              // User Role Dropdown
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DropdownButton<String>(
                        value: userRoles.contains(selectedRole)
                            ? selectedRole
                            : null,
                        hint: const Text(
                          'Select role',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        dropdownColor: const Color(0xFF2C3E50),
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
                              style: const TextStyle(fontFamily: 'Poppins'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0), // Spacing between role and status
              // User Status Dropdown
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DropdownButton<String>(
                        value:
                            ['Active', 'Pending'].contains(selectedStatusLocal)
                            ? selectedStatusLocal
                            : null,
                        hint: const Text(
                          'Select status',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        dropdownColor: const Color(0xFF2C3E50),
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
                                  style: const TextStyle(fontFamily: 'Poppins'),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0), // Spacing before the update button
          // Update Button
          ElevatedButton(
            onPressed: _updatingUserId == user.id
                ? null
                : () {
                    _updateUserRoleAndStatus(
                      user.id,
                      user.role,
                      user.status,
                      firstName: user.firstName,
                      lastName: user.lastName,
                      department: user.department,
                      designation: user.designation,
                      entity: user.entity,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
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
                : const Text('Update', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }
}
