// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../widgets/floating_circles_particle_animation.dart';
import '../widgets/profile_image_upload.dart';
import 'dart:convert';
import '../config/api_config.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _preferredNameController =
      TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _managerController = TextEditingController();

  String? _selectedDepartment;
  String? _selectedDesignation;
  String? _profileImageUrl;
  String? _profileImagePublicId;
  String _userEntity = '';
  String _userModuleAccess = '';

  final List<String> _departments = const [
    'Management',
    'Operations',
    'Finance',
    'HR',
    'Sales',
  ];

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

  Timer? _debounceTimer;
  String? _phoneError;
  String? _emailError;

  bool _validateFields() {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    bool isValid = true;

    setState(() {
      if (phone.isNotEmpty && phone.length != 10) {
        _phoneError =
            'Please enter a valid 10-digit phone number\nExample: 0123456789';
        isValid = false;
      } else {
        _phoneError = null;
      }

      if (email.isNotEmpty && !email.contains('@khonology')) {
        _emailError =
            'Please enter a valid company email\nExample: name@khonology.com';
        isValid = false;
      } else {
        _emailError = null;
      }

      if (_firstNameController.text.trim().isEmpty ||
          _surnameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        isValid = false;
      }
    });

    return isValid;
  }

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFieldChanged);
    _surnameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _preferredNameController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _onFieldChanged() {
    if (_validateFields()) {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        _saveProfile();
      });
    } else {
      _debounceTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _firstNameController.removeListener(_onFieldChanged);
    _surnameController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _preferredNameController.removeListener(_onFieldChanged);
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _preferredNameController.dispose();
    _designationController.dispose();
    _managerController.dispose();
    super.dispose();
  }

  /// Loads the logged-in user's profile from the database and displays it. Only applies data when the API response is for the current user.
  Future<void> _loadUserData() async {
    final authProvider = context.read<AuthProvider>();

    try {
      final email = authProvider.userEmail ?? '';
      if (email.isEmpty) return;

      // Always fetch from database so the profile screen shows this user's data, not cached/other user's data
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

      if (response.statusCode != 200) {
        debugPrint('Failed to fetch user info (${response.statusCode})');
        return;
      }

      final decoded = json.decode(response.body);
      Map<String, dynamic>? userMap;
      if (decoded is Map<String, dynamic>) {
        if (decoded['user'] is Map<String, dynamic>) {
          userMap = decoded['user'] as Map<String, dynamic>;
        } else {
          userMap = decoded;
        }
      }
      if (userMap == null) return;

      // Only display when the response is for the logged-in user (never show another user's data)
      final responseEmail = (userMap['email'] as String? ?? '').trim().toLowerCase();
      final currentEmail = email.trim().toLowerCase();
      if (responseEmail != currentEmail) {
        debugPrint('[StaffProfileScreen] Ignoring response: email mismatch');
        if (mounted) {
          await authProvider.updateUserProfileImage(null, null);
        }
        return;
      }

      final curEmail = email.trim().toLowerCase();
      final curEnc = curEmail.replaceAll('@', '%40');
      final firstName = (userMap['firstName'] ?? userMap['name'] ?? '').toString().trim();
      final lastName = (userMap['lastName'] ?? userMap['surname'] ?? '').toString().trim();
      final phone = (userMap['phoneNumber'] ?? '').toString().trim();
      final deptRaw = (userMap['department'] ?? '').toString().trim();
      final desigRaw = (userMap['designation'] ?? '').toString().trim();
      final preferred = (userMap['preferredName'] ?? '').toString().trim();
      final manager = (userMap['managedBy'] ?? '').toString().trim();
      String profileImageUrl = (userMap['profileImageUrl'] ?? '').toString().trim();
      String profileImagePublicId = (userMap['profileImagePublicId'] ?? '').toString().trim();
      if (profileImageUrl.isNotEmpty && !profileImageUrl.toLowerCase().contains(curEmail) && !profileImageUrl.contains(curEnc)) {
        profileImageUrl = '';
        profileImagePublicId = '';
      }
      if (profileImagePublicId.isNotEmpty && !profileImagePublicId.toLowerCase().contains(curEmail) && !profileImagePublicId.contains(curEnc)) {
        profileImageUrl = '';
        profileImagePublicId = '';
      }
      final entity = (userMap['entity'] ?? '').toString().trim();
      final moduleAccess = (userMap['moduleAccess'] ?? '').toString().trim();
      final responseEmailDisplay = (userMap['email'] ?? email).toString().trim();

      String? matchedDept;
      if (deptRaw.isNotEmpty) {
        try {
          matchedDept = _departments.firstWhere(
            (d) => d.toLowerCase() == deptRaw.toLowerCase(),
          );
        } catch (_) {
          matchedDept = null;
        }
      }

      String? matchedDesig;
      if (desigRaw.isNotEmpty) {
        try {
          matchedDesig = _designations.firstWhere(
            (d) => d.toLowerCase() == desigRaw.toLowerCase(),
          );
        } catch (_) {
          matchedDesig = null;
        }
      }

      if (mounted) {
        setState(() {
          _firstNameController.text = firstName;
          _surnameController.text = lastName;
          _emailController.text = responseEmailDisplay;
          _phoneController.text = phone;
          _preferredNameController.text = preferred;
          _managerController.text = manager;
          _selectedDepartment = matchedDept;
          _selectedDesignation = matchedDesig;
          _profileImageUrl = profileImageUrl.isNotEmpty ? profileImageUrl : null;
          _profileImagePublicId = profileImagePublicId.isNotEmpty ? profileImagePublicId : null;
          _userEntity = entity.isEmpty ? 'Not assigned' : entity;
          _userModuleAccess = moduleAccess.isNotEmpty ? moduleAccess : (authProvider.userModuleAccess ?? 'None');
        });
      }

      // Sync AuthProvider profile image: only set if this user has one, otherwise clear (no previous user's pic)
      if (mounted) {
        await authProvider.updateUserProfileImage(
          profileImageUrl.isNotEmpty ? profileImageUrl : null,
          profileImagePublicId.isNotEmpty ? profileImagePublicId : null,
        );
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void _saveProfile() async {
    if (!_validateFields()) return;

    try {
      final authProvider = context.read<AuthProvider>();
      final saveEmail = (authProvider.userEmail ?? '').trim().toLowerCase();
      final saveEnc = saveEmail.replaceAll('@', '%40');
      String saveProfileUrl = _profileImageUrl ?? '';
      String saveProfileId = _profileImagePublicId ?? '';
      if (saveProfileUrl.isNotEmpty && !saveProfileUrl.toLowerCase().contains(saveEmail) && !saveProfileUrl.contains(saveEnc)) {
        saveProfileUrl = '';
        saveProfileId = '';
      }
      if (saveProfileId.isNotEmpty && !saveProfileId.toLowerCase().contains(saveEmail) && !saveProfileId.contains(saveEnc)) {
        saveProfileUrl = '';
        saveProfileId = '';
      }
      final Map<String, dynamic> profileData = {
        'firstName': _firstNameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'department': _selectedDepartment ?? '',
        'designation': _selectedDesignation ?? '',
        'preferredName': _preferredNameController.text.trim(),
        'managedBy': _managerController.text.trim(),
        'profileImageUrl': saveProfileUrl,
        'profileImagePublicId': saveProfileId,
      };

      final response = await http.put(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/admin/users/${authProvider.userEmail}/profile',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.userToken}',
        },
        body: json.encode(profileData),
      );

      if (response.statusCode == 200) {
        debugPrint('Profile saved successfully');
      } else {
        debugPrint('Failed to save profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/nathi_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            FloatingCirclesParticleAnimation(),

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
                    ProfileImageUpload(
                      currentImageUrl: _profileImageUrl,
                      currentPublicId: _profileImagePublicId,
                      userId: authProvider.userEmail ?? 'unknown',
                      radius: 40,
                      onImageUploaded: (imageUrl, publicId) {
                        setState(() {
                          _profileImageUrl = imageUrl;
                          _profileImagePublicId = publicId;
                        });
                      },
                      onImageRemoved: () {
                        setState(() {
                          _profileImageUrl = null;
                          _profileImagePublicId = null;
                        });
                        _saveProfile(); // Persist removal to backend
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Staff Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          Text(
                            authProvider.userEmail ?? 'staff@example.com',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
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
            ),

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
                    // Entity and Modules (read-only)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildReadOnlyLabelValue('Entity', _userEntity),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildReadOnlyLabelValue(
                            'Modules Access',
                            _userModuleAccess,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
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
                                errorText: _emailError,
                              ),
                              const SizedBox(height: 16),
                              _buildEditableField(
                                'Phone Number',
                                _phoneController,
                                errorText: _phoneError,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
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
                                  _onFieldChanged();
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
                                  _onFieldChanged();
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildEditableField(
                                'Preferred Name',
                                _preferredNameController,
                              ),
                              const SizedBox(height: 16),
                              _buildEditableField(
                                'Manager',
                                _managerController,
                                readOnly: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyLabelValue(String label, String value) {
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    String? errorText,
    bool readOnly = false,
  }) {
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
            color: readOnly
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: errorText != null
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            style: TextStyle(
              color: readOnly ? Colors.white70 : Colors.white,
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              errorText: errorText,
              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                height: 0.8,
              ),
              contentPadding: const EdgeInsets.symmetric(
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
}
