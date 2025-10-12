import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String department; // Re-added department field
  final String designation;
  String role; // Default to 'Staff'
  String status; // Default to 'Active'

  // Combined name getter for UI display
  String get name => '$firstName $lastName';

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.department, // Added to constructor
    required this.designation,
    this.role = 'Staff',
    this.status = 'Active',
  });

  // Factory constructor to create a User from combined Firestore data
  factory User.fromFirestore(
    String id,
    Map<String, dynamic> userData,
    Map<String, dynamic> onboardingData,
  ) {
    return User(
      id: id,
      firstName: onboardingData['firstName'] ?? '',
      lastName: onboardingData['lastName'] ?? '',
      email: userData['email'] ?? '',
      department: onboardingData['department'] ?? '',
      designation: onboardingData['designation'] ?? '',
      role: userData['role'] ?? 'Staff', // Default to Staff if not in Firestore
      status:
          userData['status'] ??
          'Active', // Default to Active if not in Firestore
    );
  }
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _fetchedUsers = []; // List to hold fetched users
  bool _isLoading = true; // Loading state

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

  Set<String> get _availableStatuses =>
      _fetchedUsers.map((user) => user.status).toSet();
  Set<String> get _availableDepartments =>
      _fetchedUsers.map((user) => user.department).toSet();
  Set<String> get _availableDesignations =>
      _fetchedUsers.map((user) => user.designation).toSet();

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

  final List<String> userRoles = [
    'Staff',
    'Manager',
    'Admin',
    'user',
  ]; // Added 'user' to roles list

  final TextEditingController _searchController = TextEditingController();

  List<User> get _filteredUsers {
    List<User> users = _fetchedUsers;
    final query = _searchController.text.toLowerCase();

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchUsersData(); // Fetch users when the screen initializes
    _searchController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _fetchUsersData() async {
    // Renamed from _fetchOnboardingUsers
    setState(() {
      _isLoading = true;
    });
    try {
      debugPrint(
        'Attempting to fetch data from projectId: ${FirebaseFirestore.instance.app.options.projectId}',
      ); // Debug print
      // Fetch from 'users' collection
      final usersQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      List<User> usersList = [];

      for (var userDoc in usersQuerySnapshot.docs) {
        Map<String, dynamic> userData = userDoc.data();
        String userId = userDoc.id;

        // Fetch corresponding document from 'onboarding' collection
        final onboardingDoc = await FirebaseFirestore.instance
            .collection('onboarding')
            .where('user_id', isEqualTo: userId)
            .limit(1)
            .get();

        if (onboardingDoc.docs.isNotEmpty) {
          Map<String, dynamic> onboardingData = onboardingDoc.docs.first.data();
          // Combine data and create User object
          usersList.add(User.fromFirestore(userId, userData, onboardingData));
        } else {
          debugPrint('No onboarding data found for user: $userId');
          // Create user with available data, defaulting missing onboarding fields
          usersList.add(
            User(
              id: userId,
              firstName: userData['name']?.split(' ')[0] ?? '',
              lastName: userData['name']?.split(' ').length > 1
                  ? userData['name'].split(' ')[1]
                  : '',
              email: userData['email'] ?? '',
              department: '', // Default empty if no onboarding
              designation: '', // Default empty if no onboarding
              role: userData['role'] ?? 'Staff',
              status: userData['status'] ?? 'Active',
            ),
          );
        }
      }

      debugPrint(
        'Fetched ${usersList.length} users (combined from users and onboarding collections).',
      );
      setState(() {
        _fetchedUsers = usersList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users data: $e');
      setState(() {
        _isLoading = false;
      });
      // Optionally show a SnackBar or alert to the user
    }
  }

  Future<void> _updateUserRoleAndStatus(
    String userId,
    String newRole,
    String newStatus,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
        'status': newStatus,
      });
      debugPrint(
        'User $userId role updated to $newRole and status to $newStatus in Firestore.',
      );
      // Refresh the user list after updating the role and status
      _fetchUsersData();
    } catch (e) {
      debugPrint('Error updating user role and status: $e');
      // Optionally show error to user
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_fetchedUsers.isEmpty) {
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

  Widget _buildUserRow(User user, bool isExpanded) {
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
            const SizedBox(width: 16.0),
            _buildRoleBadge(user.role),
            const SizedBox(width: 8.0),
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

  Widget _buildDropdownContent(User user) {
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
                        value: selectedRole,
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
                        value: selectedStatusLocal,
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
            onPressed: () {
              _updateUserRoleAndStatus(user.id, user.role, user.status);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text(
              'Update',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }
}
