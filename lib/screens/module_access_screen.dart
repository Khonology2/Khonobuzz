import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/managed_user.dart';
import '../utils/pdh_firebase.dart';
import '../config/api_config.dart';
import '../providers/user_provider.dart';

class ModuleAccessScreen extends StatefulWidget {
  const ModuleAccessScreen({super.key});

  @override
  State<ModuleAccessScreen> createState() => _ModuleAccessScreenState();
}

class _ModuleAccessScreenState extends State<ModuleAccessScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _moduleRoleOptionsPDH = ['Employee', 'Manager'];
  static const double _designationColumnWidth = 240.0;
  static const double _badgeAreaWidth = 220.0;
  static const String _notAssignedValue = 'Not Assigned';

  String? expandedUserId;
  String? _updatingUserId; // Track which user is being updated
  Timer? _debounceTimer;
  String _searchQuery = '';

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
    final userProvider = Provider.of<UserProvider>(context);
    final users = userProvider.users;
    final query = _searchQuery.toLowerCase();

    if (query.isEmpty) return users;

    return users.where((user) {
      final moduleAccessList = (user.moduleAccess ?? '')
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();

      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.department.toLowerCase().contains(query) ||
          user.designation.toLowerCase().contains(query) ||
          moduleAccessList.any((access) => access.contains(query)) ||
          (user.moduleRole ?? '').toLowerCase().contains(query);
    }).toList();
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateModuleAccessList(
    ManagedUser user,
    bool pdhSelected,
    bool skillsHeatmapSelected,
  ) {
    List<String> accessList = [];
    if (pdhSelected) accessList.add('PDH');
    if (skillsHeatmapSelected) accessList.add('Skills Heatmap');

    user.moduleAccess = accessList.isEmpty ? null : accessList.join(',');
  }

  Future<void> _updateUserModuleAccess(
    ManagedUser user,
    bool pdhSelected,
    bool skillsHeatmapSelected,
    String? newModuleRole,
  ) async {
    setState(() {
      _updatingUserId = user.id;
    });
    // Build moduleAccess string from checkboxes
    List<String> accessList = [];
    if (pdhSelected) accessList.add('PDH');
    if (skillsHeatmapSelected) accessList.add('Skills Heatmap');

    final sanitizedModuleAccess = accessList.isEmpty
        ? ''
        : accessList.join(',');

    // Determine moduleRole based on moduleAccess
    String sanitizedModuleRole = '';
    if (pdhSelected) {
      // For PDH, use the selected role (Employee or Manager)
      sanitizedModuleRole =
          (newModuleRole != null &&
              newModuleRole.trim().isNotEmpty &&
              newModuleRole != _notAssignedValue)
          ? newModuleRole.trim()
          : '';
    }
    // Note: Skills Heatmap always has Manager role, but we don't store it separately
    // The moduleRole field is specifically for PDH

    // Create combined moduleAccessRole field
    List<String> combinedParts = [];
    if (pdhSelected && sanitizedModuleRole.isNotEmpty) {
      combinedParts.add('PDH - $sanitizedModuleRole');
    } else if (pdhSelected) {
      combinedParts.add('PDH');
    }
    if (skillsHeatmapSelected) {
      combinedParts.add('Skills Heatmap - Manager');
    }

    String combinedModuleAccess = combinedParts.isEmpty
        ? ''
        : combinedParts.join(', ');

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(user.id)),
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

      final updatedModuleAccessRole = backendUser != null
          ? (backendUser['moduleAccessRole'] as String?)?.isNotEmpty == true
                ? backendUser['moduleAccessRole'] as String
                : null
          : (combinedModuleAccess.isEmpty ? null : combinedModuleAccess);

      // Update local state with backend response
      setState(() {
        user.moduleAccess = updatedModuleAccess;
        user.moduleRole = updatedModuleRole;
      });

      // Update user in provider cache
      // ignore: use_build_context_synchronously
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.updateUser(user);

      try {
        // Sync with PDH
        await updatePDHUserPartial(
          user.id,
          {
            'moduleAccess': updatedModuleAccess,
            'moduleRole': updatedModuleRole,
            'moduleAccessRole': updatedModuleAccessRole,
          },
          onboardingFields: {
            'moduleAccess': updatedModuleAccess,
            'moduleRole': updatedModuleRole,
            'moduleAccessRole': updatedModuleAccessRole,
          },
        );
      } catch (e) {
        debugPrint('PDH sync failed for module access update: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Module access updated, but failed to sync with PDH.',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Module access updated for ${user.name}.',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFFC10D00),
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
    final moduleAccessChips = _buildModuleAccessChips(user.moduleAccess);
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12.0,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            SizedBox(
              width: _designationColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.designation,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user.department,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12.0,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16.0),
            SizedBox(
              width: _badgeAreaWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: moduleAccessChips,
                      ),
                    ),
                  ),
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

  List<Widget> _buildModuleAccessChips(String? moduleAccess) {
    if (moduleAccess == null || moduleAccess.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              _notAssignedValue,
              style: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
          ),
        ),
      ];
    }

    final accessList = moduleAccess
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (accessList.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              _notAssignedValue,
              style: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
          ),
        ),
      ];
    }

    return accessList.map((access) {
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            access,
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Colors.white,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildModuleAccessPanel(ManagedUser user) {
    // Parse moduleAccess string to list (comma-separated)
    List<String> selectedModuleAccessList = [];
    if (user.moduleAccess != null && user.moduleAccess!.isNotEmpty) {
      selectedModuleAccessList = user.moduleAccess!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Track checkbox states
    bool pdhSelected = selectedModuleAccessList.contains('PDH');
    bool skillsHeatmapSelected = selectedModuleAccessList.contains(
      'Skills Heatmap',
    );

    // Use "Not Assigned" as default if moduleRole is null or empty
    String? selectedModuleRole =
        (user.moduleRole == null || user.moduleRole!.isEmpty)
        ? _notAssignedValue
        : user.moduleRole;

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
          // PDH Row: Checkbox + Module Role Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // PDH Checkbox
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'PDH',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    value: pdhSelected,
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      setState(() {
                        pdhSelected = value ?? false;
                        _updateModuleAccessList(
                          user,
                          pdhSelected,
                          skillsHeatmapSelected,
                        );
                        // If PDH is unchecked and no role selected, clear module role
                        if (!pdhSelected &&
                            selectedModuleRole != _notAssignedValue) {
                          // Only clear if Skills Heatmap is also not selected
                          if (!skillsHeatmapSelected) {
                            selectedModuleRole = _notAssignedValue;
                            user.moduleRole = null;
                          }
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(
                width: 16.0,
              ), // Spacing between checkbox and dropdown
              // Module Role Dropdown for PDH
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: pdhSelected
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: pdhSelected
                          ? selectedModuleRole
                          : _notAssignedValue,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C3E50),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      hint: const Text(
                        'Module Role',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: pdhSelected ? Colors.white : Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                      onChanged: pdhSelected
                          ? (value) {
                              setState(() {
                                if (value == _notAssignedValue) {
                                  selectedModuleRole = _notAssignedValue;
                                  user.moduleRole = null;
                                } else {
                                  selectedModuleRole = value;
                                  user.moduleRole = value;
                                }
                              });
                            }
                          : null,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: _notAssignedValue,
                          child: Text(_notAssignedValue),
                        ),
                        ..._moduleRoleOptionsPDH.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option,
                            child: Text(option),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0), // Spacing between rows
          // Skills Heatmap Row: Checkbox + Module Role Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skills Heatmap Checkbox
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'Skills Heatmap',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    value: skillsHeatmapSelected,
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      setState(() {
                        skillsHeatmapSelected = value ?? false;
                        _updateModuleAccessList(
                          user,
                          pdhSelected,
                          skillsHeatmapSelected,
                        );
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(
                width: 16.0,
              ), // Spacing between checkbox and dropdown
              // Module Role Dropdown for Skills Heatmap
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: skillsHeatmapSelected
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: skillsHeatmapSelected
                          ? 'Manager'
                          : _notAssignedValue,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C3E50),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      hint: const Text(
                        'Module Role',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: skillsHeatmapSelected
                            ? Colors.white
                            : Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                      onChanged: skillsHeatmapSelected
                          ? (value) {
                              // Skills Heatmap always has Manager role
                              setState(() {
                                // Keep it as Manager
                              });
                            }
                          : null,
                      items: <DropdownMenuItem<String?>>[
                        if (!skillsHeatmapSelected)
                          DropdownMenuItem<String?>(
                            value: _notAssignedValue,
                            child: Text(_notAssignedValue),
                          ),
                        DropdownMenuItem<String?>(
                          value: 'Manager',
                          child: Text('Manager'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0), // Spacing before the update button
          // Update Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _updatingUserId == user.id
                  ? null
                  : () => _updateUserModuleAccess(
                      user,
                      pdhSelected,
                      skillsHeatmapSelected,
                      selectedModuleRole,
                    ),
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
                  : const Text(
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
