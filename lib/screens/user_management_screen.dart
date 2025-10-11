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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchUsersData(); // Fetch users when the screen initializes
  }

  Future<void> _fetchUsersData() async {
    // Renamed from _fetchOnboardingUsers
    setState(() {
      _isLoading = true;
    });
    try {
      debugPrint(
        'Attempting to fetch data from projectId: ${FirebaseFirestore.instance.app?.options.projectId}',
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
          SingleChildScrollView(
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
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x802C3E50),
                  foregroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: const Text(
                  'FILTER STATUS',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x802C3E50),
                  foregroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: const Text(
                  'FILTER DEPARTMENT',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x802C3E50),
                  foregroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                ),
                child: const Text(
                  'FILTER DESIGNATION',
                  style: TextStyle(fontFamily: 'Poppins'),
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
      children: _fetchedUsers.map((user) {
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
            children: [
              Container(
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: userStatusCircleColors[user.status],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8.0),
              const Text(
                'User Status: ',
                style: TextStyle(color: Colors.white60, fontFamily: 'Poppins'),
              ),
              Text(
                user.status,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
                child: const Text(
                  'User Role: ',
                  style: TextStyle(
                    color: Colors.white60,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              Expanded(
                child: Container(
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
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      expandedUserId = null;
                    });
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
