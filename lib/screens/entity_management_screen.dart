import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/managed_user.dart';

class EntityManagementScreen extends StatefulWidget {
  const EntityManagementScreen({super.key});

  @override
  State<EntityManagementScreen> createState() => _EntityManagementScreenState();
}

class _EntityManagementScreenState extends State<EntityManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _entityOptions = ['Khonology Internal'];
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
          (user.entity ?? '').toLowerCase().contains(query);
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

  Future<void> _updateUserEntity(ManagedUser user, String? newEntity) async {
    // Convert "Not Assigned" to empty string for backend
    final sanitizedEntity =
        (newEntity != null &&
            newEntity.trim().isNotEmpty &&
            newEntity != _notAssignedValue)
        ? newEntity.trim()
        : '';
    try {
      final response = await http.patch(
        Uri.parse('http://localhost:5000/api/users/${user.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': user.role,
          'status': user.status,
          'entity': sanitizedEntity,
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
      final updatedEntity = backendUser != null
          ? (backendUser['entity'] as String?)?.isNotEmpty == true
                ? backendUser['entity'] as String
                : null
          : (sanitizedEntity.isEmpty ? null : sanitizedEntity);

      setState(() {
        user.entity = updatedEntity;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Entity updated for ${user.name}.',
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
              'Failed to update entity. Please try again.',
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
            _buildEntityChip(user.entity),
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
    // Use "Not Assigned" as default if entity is null or empty
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
                    // Convert "Not Assigned" to null/empty for storage
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
              onPressed: () => _updateUserEntity(user, selectedEntity),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
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
