// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/managed_user.dart';
import '../utils/pdh_firebase.dart' show updateOnboardingUserPartial;

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  Timer? _debounceTimer;
  bool _isLoading = false;
  ManagedUser? _currentUser;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _managerController = TextEditingController();

  String? _selectedRole;
  String? _selectedDepartment;

  // Job title and department options from onboarding screen
  static const List<String> _jobTitleOptions = [
    'Director',
    'Developer',
    'Support Analyst',
    'Learner',
    'UX Designer',
    'AWS Cloud Engineer',
    'Tester',
    'RMB Small Talk Developer',
    'Finance',
    'Business Analyst',
    'Manager',
    'Delivery Manager',
    'Analyst',
    'Sales Person',
    'HR',
    'Junior Analyst',
  ];

  static const List<String> _departmentOptions = [
    'Management',
    'Operations',
    'Finance',
    'HR',
    'Sales',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _managerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    try {
      // Get current user from the users list
      final currentUser = userProvider.users
          .where((user) => user.email == authProvider.userEmail)
          .firstOrNull;

      if (currentUser != null) {
        setState(() {
          _currentUser = currentUser;
          _firstNameController.text = currentUser.firstName;
          _lastNameController.text = currentUser.lastName;
          _emailController.text = currentUser.email;
          _phoneController.text = currentUser.phoneNumber ?? '';
          _managerController.text = currentUser.manager ?? '';

          // Set dropdown values from user management data
          _selectedRole = _jobTitleOptions.contains(currentUser.designation)
              ? currentUser.designation
              : null;
          _selectedDepartment =
              _departmentOptions.contains(currentUser.department)
              ? currentUser.department
              : null;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _autoSave(String field, String value) {
    if (_currentUser == null || _isLoading) return;

    _debounceTimer?.cancel();
    setState(() {
      _isLoading = true;
    });

    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      try {
        if (_currentUser == null) return;

        // Create update map for the specific field
        final Map<String, dynamic> updateData = {};

        switch (field) {
          case 'firstName':
            updateData['firstName'] = value;
            break;
          case 'lastName':
            updateData['lastName'] = value;
            break;
          case 'role':
            updateData['designation'] = value;
            break;
          case 'department':
            updateData['department'] = value;
            break;
          case 'phone':
            updateData['phoneNumber'] = value;
            break;
        }

        await updateOnboardingUserPartial(_currentUser!.id, updateData);

        // Refresh user data
        await context.read<UserProvider>().fetchUsers();

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Auto-save error: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: null,
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
              fit: BoxFit.cover,
            ),
          ),

          // Content
          Positioned.fill(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 64.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(),

                    const SizedBox(height: 24.0),

                    // Basic Information Section
                    _buildCardSection(
                      title: 'Basic Information',
                      children: [
                        _buildInputLabel('First Name'),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _firstNameController,
                          hintText: 'First Name',
                          onChanged: (value) => _autoSave('firstName', value),
                        ),
                        const SizedBox(height: 8),
                        _buildInputLabel('Last Name'),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _lastNameController,
                          hintText: 'Last Name',
                          onChanged: (value) => _autoSave('lastName', value),
                        ),
                        const SizedBox(height: 8),
                        _buildInputLabel('Job Title / Role'),
                        const SizedBox(height: 4),
                        _buildJobTitleDropdown(),
                        const SizedBox(height: 8),
                        _buildInputLabel('Department'),
                        const SizedBox(height: 4),
                        _buildDepartmentDropdown(),
                        const SizedBox(height: 8),
                        _buildInputLabel('Email Address'),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'Work Email',
                          keyboardType: TextInputType.emailAddress,
                          enabled: false,
                        ),
                        const SizedBox(height: 8),
                        _buildInputLabel('Phone Number (Optional)'),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _phoneController,
                          hintText: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          onChanged: (value) => _autoSave('phone', value),
                        ),
                        const SizedBox(height: 8),
                        _buildInputLabel('Manager'),
                        const SizedBox(height: 4),
                        _buildTextField(
                          controller: _managerController,
                          hintText: 'Manager',
                          enabled: false,
                        ),
                      ],
                    ),

                    // Auto-save indicator
                    if (_isLoading)
                      const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFC10D00),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Saving...',
                              style: TextStyle(
                                color: Color(0xFFC10D00),
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'Profile',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          const Text(
            'These fields allow you to set up your identity, preferences, and development context.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.white70,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          ...children.map((child) {
            // Apply bottom padding only if the child is a TextFormField
            if (child.runtimeType.toString().contains('TextField') ||
                child.runtimeType.toString().contains('Dropdown')) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: child,
              );
            }
            return child;
          }),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool enabled = true,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
        filled: true,
        fillColor: Colors.grey[800]!.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildJobTitleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      dropdownColor: Colors.grey[800],
      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      decoration: InputDecoration(
        hintText: 'Select Job Title',
        hintStyle: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
        filled: true,
        fillColor: Colors.grey[800]!.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
      ),
      items: _jobTitleOptions.map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedRole = newValue;
        });
        if (newValue != null) {
          _autoSave('role', newValue);
        }
      },
    );
  }

  Widget _buildDepartmentDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDepartment,
      dropdownColor: Colors.grey[800],
      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      decoration: InputDecoration(
        hintText: 'Select Department',
        hintStyle: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
        filled: true,
        fillColor: Colors.grey[800]!.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
      ),
      items: _departmentOptions.map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedDepartment = newValue;
        });
        if (newValue != null) {
          _autoSave('department', newValue);
        }
      },
    );
  }
}
