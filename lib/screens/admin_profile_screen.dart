// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../models/managed_user.dart';
import '../utils/pdh_firebase.dart' show updateOnboardingUserPartial;
import '../config/api_config.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with SingleTickerProviderStateMixin {
  Timer? _debounceTimer;
  bool _isLoading = false;

  // Platform-specific image state variables
  File? _localImage; // Mobile only
  Uint8List? _webImageBytes; // Web only
  String? _uploadedImageUrl; // After upload (all platforms)

  ManagedUser? _currentUser;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

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

    // Initialize animation controller for heartbeat effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Add status listener to repeat the animation
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          // Web: Read image as bytes
          final bytes = await image.readAsBytes();
          setState(() {
            _webImageBytes = bytes;
            _localImage = null;
            _uploadedImageUrl = null;
          });
        } else {
          // Mobile: Store as File
          setState(() {
            _localImage = File(image.path);
            _webImageBytes = null;
            _uploadedImageUrl = null;
          });
        }
        // Auto-save profile picture
        _autoSaveProfilePicture();
      }
    } catch (e) {
      // Silent fail - no toast shown
      print('Error picking image: $e');
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty &&
          !uri.host.contains(' ') &&
          !url.contains(' ');
    } catch (e) {
      return false;
    }
  }

  Future<void> _autoSaveProfilePicture() async {
    if (_currentUser == null) return;
    
    // Check if we have an image to upload
    if (kIsWeb && _webImageBytes == null) return;
    if (!kIsWeb && _localImage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String imageUrl;
      
      if (kIsWeb) {
        // Web: Upload bytes directly
        imageUrl = await _uploadBytesToBackend(_webImageBytes!);
      } else {
        // Mobile: Upload file
        imageUrl = await _uploadToBackend(_localImage!);
      }

      if (imageUrl.isNotEmpty) {
        // Update user profile with ImageKit URL
        await updateOnboardingUserPartial(_currentUser!.id, {
          'profilePictureUrl': imageUrl,
        });

        // Update local user data
        final userProvider = context.read<UserProvider>();
        await userProvider.fetchUsers(forceRefresh: true);
        _loadUserData();

        // Clear local state and set uploaded URL
        setState(() {
          _uploadedImageUrl = imageUrl;
          _localImage = null;
          _webImageBytes = null;
        });

        print('Admin profile picture uploaded successfully: $imageUrl');
      } else {
        throw Exception('Received empty URL from backend');
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload profile picture'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _uploadBytesToBackend(Uint8List imageBytes) async {

  Future<String> _uploadToBackend(File imageFile) async {
    try {
      // Validate file exists and is readable
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        // 5MB limit
        throw Exception('Image file too large (max 5MB)');
      }

      // Get current user ID for folder organization
      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();
      final currentUser = userProvider.users
          .where((user) => user.email == authProvider.userEmail)
          .firstOrNull;

      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Create multipart request to new ImageKit endpoint
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/users/profile-image'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'multipart/form-data',
      });

      // Add user_id parameter
      request.fields['user_id'] = currentUser.id;

      // Add file with proper content type
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'admin_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      request.files.add(multipartFile);

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
          'Upload timeout - please check your internet connection',
        ),
      );

      // Get response body
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }

      if (response.body.isEmpty) {
        throw Exception('Empty response from server');
      }

      // Parse JSON response from new ImageKit endpoint
      final jsonResponse = json.decode(response.body);

      // New endpoint returns {"url": "...", "file_id": "..."}
      final url = jsonResponse['url'] as String?;
      if (url != null && url.isNotEmpty) {
        print('Admin profile picture uploaded successfully to ImageKit: $url');
        return url;
      } else {
        final error = jsonResponse['error'] ?? 'Unknown upload error';
        throw Exception('Upload failed: $error');
      }
    } catch (e) {
      print('Admin backend upload error: $e');
      rethrow;
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

        // Add profile picture URL if it exists
        if (_profileImage != null) {
          try {
            String imageUrl = await _uploadToBackend(_profileImage!);
            if (imageUrl.isNotEmpty) {
              updateData['profilePictureUrl'] = imageUrl;
            }
          } catch (e) {
            print('Admin backend upload failed during auto-save: $e');
            // Keep existing URL if upload fails
          }
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
    final userName = '${_firstNameController.text} ${_lastNameController.text}'
        .trim();
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

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
              'Admin Profile',
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
          const SizedBox(height: 24.0),

          // Profile Photo Section - Centered at the top
          Center(
            child: Column(
              children: [
                MouseRegion(
                  onEnter: (_) => _animationController.forward(),
                  onExit: (_) => _animationController.reverse(),
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _profileImage != null
                                      ? Image.file(
                                          _profileImage!,
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                print(
                                                  'Error loading admin local image: $error',
                                                );
                                                return _buildDefaultAvatar(
                                                  userInitial,
                                                  100,
                                                );
                                              },
                                        )
                                      : _isValidUrl(
                                          _currentUser?.profilePictureUrl,
                                        )
                                      ? Image.network(
                                          _currentUser!.profilePictureUrl!,
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                print(
                                                  'Error loading profile image: $error',
                                                );
                                                return _buildDefaultAvatar(
                                                  _currentUser!
                                                          .firstName
                                                          .isNotEmpty
                                                      ? _currentUser!
                                                            .firstName[0]
                                                            .toUpperCase()
                                                      : 'A',
                                                  100,
                                                );
                                              },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value:
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                    : null,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            );
                                          },
                                        )
                                      : _buildDefaultAvatar(userInitial, 100),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC10D00),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upload Photo',
                  style: TextStyle(
                    color: Color(0xFFC10D00),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFC10D00),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
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
