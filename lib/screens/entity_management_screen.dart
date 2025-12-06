import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/managed_user.dart';
import '../utils/pdh_firebase.dart'
    show updatePDHUserPartial, updateSkillsHeatmapUserPartial;
import '../config/api_config.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';

class EntityManagementScreen extends StatefulWidget {
  const EntityManagementScreen({super.key});

  @override
  State<EntityManagementScreen> createState() => _EntityManagementScreenState();
}

class _EntityManagementScreenState extends State<EntityManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _entityOptions = ['Khonology Internal'];
  static const String _notAssignedValue = 'Not Assigned';

  String? expandedUserId;
  String? _updatingUserId;
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
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.department.toLowerCase().contains(query) ||
          user.designation.toLowerCase().contains(query) ||
          (user.entity ?? '').toLowerCase().contains(query);
    }).toList();
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateUserEntity(ManagedUser user, String? newEntity) async {
    final adminEmail = context.read<AuthProvider>().userEmail?.trim() ?? '';
    setState(() {
      _updatingUserId = user.id;
    });

    final sanitizedEntity =
        (newEntity != null &&
            newEntity.trim().isNotEmpty &&
            newEntity != _notAssignedValue)
        ? newEntity.trim()
        : '';
    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(user.id)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': user.role,
          'status': user.status,
          'entity': sanitizedEntity,
          if (adminEmail.isNotEmpty) 'adminApproved': adminEmail,
        }),
      );

      final decodedResp = jsonDecode(response.body) as Map<String, dynamic>?;
      if (response.statusCode != 200 || decodedResp == null) {
        throw Exception(
          'Failed to update user ${user.id}: ${response.statusCode}',
        );
      }

      final backendUser = decodedResp['user'] as Map<String, dynamic>?;
      final updatedEntity = backendUser != null
          ? (backendUser['entity'] as String?)?.isNotEmpty == true
                ? backendUser['entity'] as String
                : null
          : (sanitizedEntity.isEmpty ? null : sanitizedEntity);

      setState(() {
        user.entity = updatedEntity;
      });

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.updateUser(user);
      }

      final adminField = adminEmail.isNotEmpty
          ? {
              'admin': {'approved': adminEmail},
            }
          : null;

      try {
        await updatePDHUserPartial(
          user.id,
          {'entity': updatedEntity, if (adminField != null) ...adminField},
          onboardingFields: {
            'entity': updatedEntity,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('PDH sync failed for entity update: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Entity updated, but failed to sync with PDH.',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      try {
        await updateSkillsHeatmapUserPartial(
          user.id,
          {'entity': updatedEntity, if (adminField != null) ...adminField},
          onboardingFields: {
            'entity': updatedEntity,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('Skills Heatmap sync failed for entity update: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Entity updated for ${user.name}.',
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
              'Failed to update entity. Please try again.',
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
          'Entity Management',
          style: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          'Assign entities to keep user records up to date.',
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
              if (isExpanded) _buildEntityPanel(user),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final spacingWidth = 8.0 * 2;
            final columnWidth = (availableWidth - spacingWidth) / 3;
            final leftPadding = columnWidth * 0.12;

            final secondColumnWidth = columnWidth - leftPadding;

            return Row(
              children: [
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
                      Flexible(child: _buildEntityChip(user.entity)),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildEntityChip(String? entity) {
    final displayText = (entity == null || entity.isEmpty)
        ? _notAssignedValue
        : entity;

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

  Widget _buildEntityPanel(ManagedUser user) {
    String? selectedEntity = (user.entity == null || user.entity!.isEmpty)
        ? _notAssignedValue
        : user.entity;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entity Assignment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 16.0),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: DropdownButton<String?>(
                value: selectedEntity,
                isExpanded: true,
                dropdownColor: const Color(0xFF2C3E50),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
                onChanged: (value) {
                  setState(() {
                    if (value == _notAssignedValue) {
                      selectedEntity = _notAssignedValue;
                      user.entity = null;
                    } else {
                      selectedEntity = value;
                      user.entity = value;
                    }
                  });
                },
                items: <DropdownMenuItem<String?>>[
                  DropdownMenuItem<String?>(
                    value: _notAssignedValue,
                    child: Text(_notAssignedValue),
                  ),
                  ..._entityOptions.map(
                    (option) => DropdownMenuItem<String?>(
                      value: option,
                      child: Text(option),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _updatingUserId == user.id
                  ? null
                  : () => _updateUserEntity(user, selectedEntity),
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
                      'Update Entity',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
