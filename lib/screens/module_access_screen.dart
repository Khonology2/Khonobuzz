import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/managed_user.dart';

class ModuleAccessScreen extends StatefulWidget {
  const ModuleAccessScreen({super.key});

  @override
  State<ModuleAccessScreen> createState() => _ModuleAccessScreenState();
}

class _ModuleAccessScreenState extends State<ModuleAccessScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _moduleAccessOptions = ['PDH', 'SOW Builder'];
  final List<String> _moduleRoleOptionsPDH = ['Employee', 'Manager'];
  final List<String> _moduleRoleOptionsSOW = ['Manager'];
  static const String _notAssignedValue = 'Not Assigned';

  List<ManagedUser> _users = [];
  bool _isLoading = true;
  String? expandedUserId;

  Map<String, Color> get userStatusColors => {
    'Active': Colors.green.shade600,
    'Inactive': Colors.grey.shade600,
    'Pending': Colors.orange.shade500,
  };

  Map<String, Color> get userRoleColors => {
    'Staff': Colors.blue.shade600,
    'Manager': Colors.purple.shade600,
    'Admin': const Color(0xFFC10D00),
  };

  List<ManagedUser> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _users;

    return _users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.department.toLowerCase().contains(query) ||
          user.designation.toLowerCase().contains(query) ||
          (user.moduleAccess ?? '').toLowerCase().contains(query) ||
          (user.moduleRole ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/users'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch users: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final usersData = (decoded['users'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final users = usersData
          .map((user) => ManagedUser.fromApi(user))
          .toList(growable: false);

      users.sort((a, b) {
        final aKey =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bKey =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bKey.compareTo(aKey);
      });

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load users. Please try again.',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _updateUserModuleAccess(
    ManagedUser user,
    String? newModuleAccess,
    String? newModuleRole,
  ) async {
    // Convert "Not Assigned" to empty string for backend
    final sanitizedModuleAccess =
        (newModuleAccess != null &&
            newModuleAccess.trim().isNotEmpty &&
            newModuleAccess != _notAssignedValue)
        ? newModuleAccess.trim()
        : '';

    // Determine moduleRole based on moduleAccess
    String sanitizedModuleRole = '';
    if (sanitizedModuleAccess == 'PDH') {
      // For PDH, use the selected role (Employee or Manager)
      sanitizedModuleRole =
          (newModuleRole != null &&
              newModuleRole.trim().isNotEmpty &&
              newModuleRole != _notAssignedValue)
          ? newModuleRole.trim()
          : '';
    } else if (sanitizedModuleAccess == 'SOW Builder') {
      // For SOW Builder, always set to Manager
      sanitizedModuleRole = 'Manager';
    }

    // Create combined moduleAccess field: "PDH - Employee", "PDH - Manager", or "SOW Builder - Manager"
    String combinedModuleAccess = '';
    if (sanitizedModuleAccess.isNotEmpty && sanitizedModuleRole.isNotEmpty) {
      combinedModuleAccess = '$sanitizedModuleAccess - $sanitizedModuleRole';
    } else if (sanitizedModuleAccess.isNotEmpty) {
      combinedModuleAccess = sanitizedModuleAccess;
    }

    try {
      final response = await http.patch(
        Uri.parse('http://localhost:5000/api/users/${user.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': user.role,
          'status': user.status,
          'moduleAccess': sanitizedModuleAccess,
          'moduleRole': sanitizedModuleRole,
          'moduleAccessRole': combinedModuleAccess, // Combined field
        }),
      );

      final decodedResp = jsonDecode(response.body) as Map<String, dynamic>?;
      if (response.statusCode != 200 || decodedResp == null) {
        throw Exception(
          'Failed to update user ${user.id}: ${response.statusCode}',
        );
      }

      // If backend returned updated user payload, prefer that canonical source
      final backendUser = decodedResp['user'] as Map<String, dynamic>?;
      final updatedModuleAccess = backendUser != null
          ? (backendUser['moduleAccess'] as String?)?.isNotEmpty == true
                ? backendUser['moduleAccess'] as String
                : null
          : (sanitizedModuleAccess.isEmpty ? null : sanitizedModuleAccess);

      final updatedModuleRole = backendUser != null
          ? (backendUser['moduleRole'] as String?)?.isNotEmpty == true
                ? backendUser['moduleRole'] as String
                : null
          : (sanitizedModuleRole.isEmpty ? null : sanitizedModuleRole);

      setState(() {
        user.moduleAccess = updatedModuleAccess;
        user.moduleRole = updatedModuleRole;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Module access updated for ${user.name}.',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update module access. Please try again.',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      await _fetchUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16.0),
                    _buildSearch(),
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
          'Module Access',
          style: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          'Assign module access and roles to manage user permissions.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14.0,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search users',
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
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFC10D00)),
            const SizedBox(height: 24.0),
            Text(
              'Fetching user records...',
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

    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
      );
    }

    return Column(
      children: _filteredUsers.map((user) {
        final isExpanded = expandedUserId == user.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            children: [
              _buildUserRow(user, isExpanded),
              if (isExpanded) _buildModuleAccessPanel(user),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.designation,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    user.department,
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
            if ((user.role).toLowerCase() != 'user') ...[
              _buildRoleBadge(user.role),
              const SizedBox(width: 8.0),
            ],
            _buildStatusBadge(user.status),
            const SizedBox(width: 8.0),
            _buildModuleAccessChip(user.moduleAccess),
            const SizedBox(width: 8.0),
            if (user.moduleAccess == 'PDH' && user.moduleRole != null)
              _buildModuleRoleChip(user.moduleRole),
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
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: userRoleColors[role] ?? Colors.blueGrey.shade600,
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
        color: userStatusColors[status] ?? Colors.grey.shade600,
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

  Widget _buildModuleAccessChip(String? moduleAccess) {
    final displayText = (moduleAccess == null || moduleAccess.isEmpty)
        ? _notAssignedValue
        : moduleAccess;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildModuleRoleChip(String? moduleRole) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.purple.shade600.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        moduleRole ?? '',
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildModuleAccessPanel(ManagedUser user) {
    // Use "Not Assigned" as default if moduleAccess is null or empty
    String? selectedModuleAccess =
        (user.moduleAccess == null || user.moduleAccess!.isEmpty)
        ? _notAssignedValue
        : user.moduleAccess;

    // Use "Not Assigned" as default if moduleRole is null or empty
    String? selectedModuleRole =
        (user.moduleRole == null || user.moduleRole!.isEmpty)
        ? _notAssignedValue
        : user.moduleRole;

    // Module Role is enabled when Module Access is PDH or SOW Builder
    final bool isModuleRoleEnabled =
        selectedModuleAccess == 'PDH' || selectedModuleAccess == 'SOW Builder';

    // Get appropriate role options based on module access
    final List<String> roleOptions = selectedModuleAccess == 'PDH'
        ? _moduleRoleOptionsPDH
        : (selectedModuleAccess == 'SOW Builder' ? _moduleRoleOptionsSOW : []);

    // If SOW Builder is selected and no role is set, default to Manager
    if (selectedModuleAccess == 'SOW Builder' &&
        selectedModuleRole == _notAssignedValue) {
      selectedModuleRole = 'Manager';
      user.moduleRole = 'Manager';
    }

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
              // Module Access Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Module Access: ',
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedModuleAccess,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C3E50),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                          onChanged: (value) {
                            setState(() {
                              // Convert "Not Assigned" to null/empty for storage
                              if (value == _notAssignedValue) {
                                selectedModuleAccess = _notAssignedValue;
                                user.moduleAccess = null;
                                // Clear moduleRole when moduleAccess is cleared
                                selectedModuleRole = _notAssignedValue;
                                user.moduleRole = null;
                              } else {
                                selectedModuleAccess = value;
                                user.moduleAccess = value;
                                // If SOW Builder is selected, automatically set role to Manager
                                if (value == 'SOW Builder') {
                                  selectedModuleRole = 'Manager';
                                  user.moduleRole = 'Manager';
                                } else if (value != 'PDH') {
                                  // Clear moduleRole if moduleAccess is not PDH or SOW Builder
                                  selectedModuleRole = _notAssignedValue;
                                  user.moduleRole = null;
                                }
                              }
                            });
                          },
                          items: <DropdownMenuItem<String?>>[
                            DropdownMenuItem<String?>(
                              value: _notAssignedValue,
                              child: Text(_notAssignedValue),
                            ),
                            ..._moduleAccessOptions.map(
                              (option) => DropdownMenuItem<String?>(
                                value: option,
                                child: Text(option),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0), // Spacing between dropdowns
              // Module Role Dropdown (only enabled when Module Access is PDH)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Module Role: ',
                      style: TextStyle(
                        color: Colors.white60,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: isModuleRoleEnabled
                            ? const Color(0xFF2C3E50)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: isModuleRoleEnabled
                              ? (selectedModuleAccess == 'SOW Builder'
                                    ? 'Manager'
                                    : selectedModuleRole)
                              : _notAssignedValue,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C3E50),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          style: TextStyle(
                            color: isModuleRoleEnabled
                                ? Colors.white
                                : Colors.white54,
                            fontFamily: 'Poppins',
                          ),
                          onChanged: isModuleRoleEnabled
                              ? (value) {
                                  setState(() {
                                    // For SOW Builder, value should always be Manager
                                    if (selectedModuleAccess == 'SOW Builder') {
                                      selectedModuleRole = 'Manager';
                                      user.moduleRole = 'Manager';
                                    } else {
                                      // Convert "Not Assigned" to null/empty for storage
                                      if (value == _notAssignedValue) {
                                        selectedModuleRole = _notAssignedValue;
                                        user.moduleRole = null;
                                      } else {
                                        selectedModuleRole = value;
                                        user.moduleRole = value;
                                      }
                                    }
                                  });
                                }
                              : null,
                          items: <DropdownMenuItem<String?>>[
                            if (selectedModuleAccess != 'SOW Builder')
                              DropdownMenuItem<String?>(
                                value: _notAssignedValue,
                                child: Text(_notAssignedValue),
                              ),
                            ...roleOptions.map(
                              (option) => DropdownMenuItem<String?>(
                                value: option,
                                child: Text(option),
                              ),
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
          const SizedBox(height: 16.0), // Spacing before the update button
          // Update Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _updateUserModuleAccess(
                user,
                selectedModuleAccess,
                selectedModuleRole,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Update Module Access',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
