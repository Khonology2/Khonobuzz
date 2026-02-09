import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class ProfileImageUpload extends StatefulWidget {
  final String? currentImageUrl;
  final String? currentPublicId;
  final String userId;
  final double radius;
  final Function(String imageUrl, String publicId)? onImageUploaded;
  final Function()? onImageRemoved;

  const ProfileImageUpload({
    super.key,
    this.currentImageUrl,
    this.currentPublicId,
    required this.userId,
    this.radius = 40.0,
    this.onImageUploaded,
    this.onImageRemoved,
  });

  @override
  State<ProfileImageUpload> createState() => _ProfileImageUploadState();
}

class _ProfileImageUploadState extends State<ProfileImageUpload> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _imageUrl;
  String? _publicId;

  @override
  void initState() {
    super.initState();
    // Initialize with AuthProvider data for persistence
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _imageUrl = authProvider.userProfileImageUrl ?? widget.currentImageUrl;
    _publicId = authProvider.userProfilePublicId ?? widget.currentPublicId;

    debugPrint(
      '[ProfileImageUpload] initState - AuthProvider URL: ${authProvider.userProfileImageUrl}',
    );
    debugPrint(
      '[ProfileImageUpload] initState - AuthProvider PublicId: ${authProvider.userProfilePublicId}',
    );
    debugPrint('[ProfileImageUpload] initState - Final URL: $_imageUrl');
    debugPrint('[ProfileImageUpload] initState - Final PublicId: $_publicId');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update when AuthProvider changes (e.g., after login)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userProfileImageUrl != _imageUrl ||
        authProvider.userProfilePublicId != _publicId) {
      setState(() {
        _imageUrl = authProvider.userProfileImageUrl ?? widget.currentImageUrl;
        _publicId = authProvider.userProfilePublicId ?? widget.currentPublicId;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadImage(image);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (photo != null) {
        await _uploadImage(photo);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to take photo: $e');
    }
  }

  Future<void> _uploadImage(dynamic imageFile) async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Debug logging
      debugPrint('[ProfileImageUpload] Starting image upload...');
      debugPrint('[ProfileImageUpload] User ID: ${widget.userId}');
      if (!kIsWeb) {
        debugPrint('[ProfileImageUpload] Image file: ${imageFile.path}');
      }
      debugPrint('[ProfileImageUpload] Is Web: $kIsWeb');
      debugPrint(
        '[ProfileImageUpload] API URL: ${ApiConfig.baseUrl}/users/profile-image',
      );

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/users/profile-image?user_id=${Uri.encodeComponent(widget.userId)}',
        ),
      );

      debugPrint(
        '[ProfileImageUpload] Added user_id as query parameter: ${widget.userId}',
      );

      // Handle file differently for web vs mobile
      Uint8List imageBytes;
      String fileName;

      if (kIsWeb) {
        // For web, use the XFile's readAsBytes method
        fileName =
            imageFile.name ??
            'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageBytes = await imageFile.readAsBytes();
        debugPrint('[ProfileImageUpload] Web: Reading bytes from XFile');
      } else {
        // For mobile, use File
        final file = imageFile as File;
        fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageBytes = await file.readAsBytes();
        debugPrint('[ProfileImageUpload] Mobile: Reading bytes from File');
      }

      debugPrint('[ProfileImageUpload] Image size: ${imageBytes.length} bytes');

      // Add image file
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);
      debugPrint(
        '[ProfileImageUpload] Added image file: ${multipartFile.filename}',
      );

      // Send request
      debugPrint('[ProfileImageUpload] Sending request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[ProfileImageUpload] Response received:');
      debugPrint('[ProfileImageUpload] Status Code: ${response.statusCode}');
      debugPrint('[ProfileImageUpload] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          setState(() {
            _imageUrl = responseData['url'];
            _publicId = responseData['public_id'];
          });

          // Save to AuthProvider for persistence
          if (mounted) {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            await authProvider.updateUserProfileImage(
              responseData['url'] ?? '',
              responseData['public_id'] ?? '',
            );
          }

          widget.onImageUploaded?.call(_imageUrl ?? '', _publicId ?? '');
          _showSuccessSnackBar('Profile image updated successfully!');
          debugPrint('[ProfileImageUpload] Upload successful!');
        } else {
          throw Exception(responseData['error'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ProfileImageUpload] Upload failed: $e');
      _showErrorSnackBar('Failed to upload image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _removeImage() async {
    if (_publicId == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/delete/profile-picture'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'public_id': _publicId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _imageUrl = null;
          _publicId = null;
        });

        // Clear from AuthProvider
        if (mounted) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.updateUserProfileImage('', '');
        }

        widget.onImageRemoved?.call();
        _showSuccessSnackBar('Profile image removed successfully!');
      } else {
        throw Exception('Failed to remove image');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to remove image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showImageOptions() {
    // Debug logging
    debugPrint('[ProfileImageUpload] Show image options tapped');
    debugPrint('[ProfileImageUpload] Current user ID: ${widget.userId}');
    debugPrint('[ProfileImageUpload] Current image URL: $_imageUrl');
    debugPrint('[ProfileImageUpload] Current public ID: $_publicId');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1a1a1a),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Profile Picture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                if (_imageUrl != null) ...[
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removeImage();
                    },
                  ),
                  const Divider(height: 1, color: Colors.grey),
                ],
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFFC10D00),
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  onTap: () {
                    debugPrint('[ProfileImageUpload] Camera option selected');
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFFC10D00),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  onTap: () {
                    debugPrint('[ProfileImageUpload] Gallery option selected');
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC10D00),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get AuthProvider data without Consumer to avoid conflicts
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final displayImageUrl = authProvider.userProfileImageUrl ?? _imageUrl;

    debugPrint(
      '[ProfileImageUpload] Build - AuthProvider URL: ${authProvider.userProfileImageUrl}',
    );
    debugPrint('[ProfileImageUpload] Build - Local URL: $_imageUrl');
    debugPrint('[ProfileImageUpload] Build - Display URL: $displayImageUrl');

    return GestureDetector(
      onTap: _showImageOptions,
      child: Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: Colors.grey[300],
            backgroundImage: displayImageUrl != null
                ? NetworkImage(displayImageUrl)
                : null,
            child: displayImageUrl != null
                ? null
                : Icon(
                    Icons.person,
                    size: widget.radius * 0.8,
                    color: Colors.grey[600],
                  ),
          ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: widget.radius * 0.4,
              height: widget.radius * 0.4,
              decoration: BoxDecoration(
                color: const Color(0xFFC10D00),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                displayImageUrl != null ? Icons.edit : Icons.add,
                color: Colors.white,
                size: widget.radius * 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
