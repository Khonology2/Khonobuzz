// ignore_for_file: deprecated_member_use, unnecessary_const, unused_element, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../widgets/floating_circles_particle_animation.dart';
import '../widgets/version_control.dart';
import 'dart:convert';
import '../config/api_config.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  AdminProfileScreenState createState() => AdminProfileScreenState();
}

class AdminProfileScreenState extends State<AdminProfileScreen> {
  // Text editing controllers
  late TextEditingController _firstNameController;
  late TextEditingController _surnameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _preferredNameController;
  late TextEditingController _designationController;

  // Dropdown options
  final List<String> _departments = const [
    'Management',
    'Operations',
    'Finance',
    'HR',
    'Sales',
  ];
  String? _selectedDepartment;

  final List<String> _designations = const [
    'Director',
    'Developer',
    'Support Analyst',
    'Learner',
    'UX Designer',
    'AWS Cloud Engineer',
    'Tester',
    'Finance',
    'Business Analyst',
    'Manager',
    'Delivery Manager',
    'Analyst',
    'Sales Person',
    'HR',
    'Junior Analyst',
  ];
  String? _selectedDesignation;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty fields for user input
    _firstNameController = TextEditingController();
    _surnameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _departmentController = TextEditingController();
    _preferredNameController = TextEditingController();
    _designationController = TextEditingController();

    // Initialize dropdown selections
    _selectedDepartment = null;
    _selectedDesignation = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    final authProvider = context.read<AuthProvider>();

    try {
      final email = authProvider.userEmail ?? '';
      if (email.isEmpty) return;
      final url = Uri.parse(ApiConfig.userByEmailEndpoint(email));
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer ${authProvider.userToken}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        Map<String, dynamic> userMap = {};
        if (decoded is Map<String, dynamic>) {
          if (decoded['user'] is Map<String, dynamic>) {
            userMap = decoded['user'] as Map<String, dynamic>;
          } else {
            userMap = decoded;
          }
        }

        final firstName = (userMap['firstName'] ?? userMap['name'] ?? '').toString();
        final lastName = (userMap['lastName'] ?? userMap['surname'] ?? '').toString();
        final phone = (userMap['phoneNumber'] ?? '').toString();
        final deptRaw = (userMap['department'] ?? '').toString().trim();
        final desigRaw = (userMap['designation'] ?? '').toString().trim();
        final preferred = (userMap['preferredName'] ?? '').toString();

        // Robust matching for dropdowns
        String? matchedDept;
        if (deptRaw.isNotEmpty) {
          matchedDept = _departments.firstWhere(
            (d) => d.toLowerCase() == deptRaw.toLowerCase(),
            orElse: () => '',
          );
          if (matchedDept.isEmpty) matchedDept = null;
        }

        String? matchedDesig;
        if (desigRaw.isNotEmpty) {
          matchedDesig = _designations.firstWhere(
            (d) => d.toLowerCase() == desigRaw.toLowerCase(),
            orElse: () => '',
          );
          if (matchedDesig.isEmpty) matchedDesig = null;
        }

        setState(() {
          _firstNameController.text = firstName;
          _surnameController.text = lastName;
          _emailController.text = email;
          _phoneController.text = phone;
          _preferredNameController.text = preferred;
          _selectedDepartment = matchedDept;
          _selectedDesignation = matchedDesig;
        });
      } else {
        debugPrint('Failed to fetch user info (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _preferredNameController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
      // Validate required fields
      if (_firstNameController.text.trim().isEmpty ||
          _surnameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fill in First Name, Surname, and Email Address',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save profile to database via API
      try {
        final authProvider = context.read<AuthProvider>();

        // Create user profile data object
        final Map<String, dynamic> profileData = {
          'firstName': _firstNameController.text.trim(),
          'surname': _surnameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'department': _selectedDepartment ?? '',
          'designation': _selectedDesignation ?? '',
          'preferredName': _preferredNameController.text.trim(),
        };

        debugPrint('=== SAVING PROFILE TO DATABASE ===');
        debugPrint('User Email: ${authProvider.userEmail}');
        debugPrint('Profile Data: $profileData');
        debugPrint('Saving to onboarding collection...');

        // Make API call to save profile data
        final response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/admin/users/${authProvider.userEmail}/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${authProvider.userToken}',
          },
          body: json.encode(profileData),
        );

        if (response.statusCode == 200) {
          debugPrint('Profile saved successfully to database');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Profile information saved successfully!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                  ),
                ),
                backgroundColor: const Color(0xFFC10D00),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          debugPrint('Failed to save profile: ${response.statusCode}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to save profile. Please try again.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error saving profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save profile. Please try again.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    Widget _buildEditableField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    TextEditingController controller,
    String? initialValue,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonFormField<String>(
            value: initialValue,
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[800]!.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
            ),
            hint: Text(
              'Select $label',
              style: TextStyle(color: Colors.grey[600], fontFamily: 'Poppins'),
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(value: item, child: Text(item));
            }).toList(),
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a $label';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            FloatingCirclesParticleAnimation(),

            // Back button at top left
            Positioned(
              top: 40,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),

            // Admin Profile Header at top
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFC10D00).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFFC10D00),
                      child: Text(
                        authProvider.userEmail?.substring(0, 2).toUpperCase() ??
                            'AD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          Text(
                            authProvider.userEmail ?? 'admin@example.com',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Editable Fields Widget - Separate from profile widget
            Positioned(
              top: 280,
              left: 16,
              right: 16,
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFC10D00).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two-column layout for fields
                    Row(
                      children: [
                        // Left column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEditableField(
                                'First Name',
                                _firstNameController,
                              ),
                              const SizedBox(height: 16),
                              _buildEditableField(
                                'Surname',
                                _surnameController,
                              ),
                              const SizedBox(height: 16),
                              _buildEditableField(
                                'Email Address',
                                _emailController,
                              ),
                              const SizedBox(height: 16),
                              _buildEditableField(
                                'Phone Number',
                                _phoneController,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownField(
                                'Department',
                                _departmentController,
                                _selectedDepartment,
                                _departments,
                                (String? newValue) {
                                  setState(() {
                                    _selectedDepartment = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildDropdownField(
                                'Designation',
                                _designationController,
                                _selectedDesignation,
                                _designations,
                                (String? newValue) {
                                  setState(() {
                                    _selectedDesignation = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildEditableField(
                                'Preferred Name',
                                _preferredNameController,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'SAVE',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const VersionControlOverlay(),
          ],
        ),
      ),
    );
  }
}
