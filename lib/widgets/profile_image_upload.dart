import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/sound_system.dart';

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
    this.radius = 40,
    this.onImageUploaded,
    this.onImageRemoved,
  });

  @override
  State<ProfileImageUpload> createState() => _ProfileImageUploadState();
}

class _ProfileImageUploadState extends State<ProfileImageUpload> {
  String? _imageUrl;
  String? _publicId;
  bool _isUploading = false;

  /// Use screen-provided image first. For current user, only use AuthProvider when screen has not yet provided data (initial load).
  /// When screen explicitly passes null/empty after loading, use that so we never show a previous user's picture.
  void _resolveImageFromProps() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCurrentUser = authProvider.userEmail != null &&
        widget.userId.trim().toLowerCase() == authProvider.userEmail!.trim().toLowerCase();
    final hasWidgetImage = (widget.currentImageUrl ?? '').trim().isNotEmpty ||
        (widget.currentPublicId ?? '').trim().isNotEmpty;
    if (hasWidgetImage) {
      _imageUrl = widget.currentImageUrl;
      _publicId = widget.currentPublicId;
    } else if (isCurrentUser) {
      // Use AuthProvider only for current user; profile screen syncs AuthProvider when loading, so this stays in sync
      final apUrl = authProvider.userProfileImageUrl;
      final apId = authProvider.userProfilePublicId;
      final apHasImage = (apUrl ?? '').trim().isNotEmpty || (apId ?? '').trim().isNotEmpty;
      if (apHasImage) {
        _imageUrl = apUrl;
        _publicId = apId;
      } else {
        _imageUrl = null;
        _publicId = null;
      }
    } else {
      _imageUrl = null;
      _publicId = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveImageFromProps();
    debugPrint('[ProfileImageUpload] initState - userId: ${widget.userId}');
    debugPrint('[ProfileImageUpload] initState - Final URL: $_imageUrl');
    debugPrint('[ProfileImageUpload] initState - Final PublicId: $_publicId');
  }

  @override
  void didUpdateWidget(ProfileImageUpload oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentImageUrl != widget.currentImageUrl ||
        oldWidget.currentPublicId != widget.currentPublicId) {
      _resolveImageFromProps();
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prevUrl = _imageUrl;
    final prevId = _publicId;
    _resolveImageFromProps();
    if (mounted && (prevUrl != _imageUrl || prevId != _publicId)) setState(() {});
  }

  Future<void> _showImageOptions() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFFC10D00),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  SoundSystem.playButtonClick();
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFC10D00)),
                title: const Text('Take Photo'),
                onTap: () {
                  SoundSystem.playButtonClick();
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_imageUrl != null || (_publicId != null && _publicId!.isNotEmpty))
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    SoundSystem.playButtonClick();
                    Navigator.pop(context);
                    _removeImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        // Read image as bytes for all platforms to avoid _Namespace error
        final bytes = await image.readAsBytes();
        await _uploadImageBytes(image.name, bytes);
      }
    } catch (e) {
      debugPrint('[ProfileImageUpload] Image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImageBytes(String fileName, Uint8List imageBytes) async {
    if (!mounted) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/users/profile-image?user_id=${widget.userId}',
        ),
      );

      // Add image file from bytes
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);

      // Add auth header
      if (authProvider.userToken != null) {
        request.headers['Authorization'] = 'Bearer ${authProvider.userToken}';
      }

      debugPrint(
        '[ProfileImageUpload] Uploading image to: ${ApiConfig.baseUrl}/users/profile-image?user_id=${widget.userId}',
      );
      debugPrint('[ProfileImageUpload] Image size: ${imageBytes.length} bytes');

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      debugPrint(
        '[ProfileImageUpload] Response status: ${response.statusCode}',
      );
      debugPrint('[ProfileImageUpload] Response body: $responseBody');

      if (response.statusCode == 200 && responseData['success'] == true) {
        final imageUrl = responseData['url'];
        final publicId = responseData['public_id'];

        debugPrint(
          '[ProfileImageUpload] Upload successful - URL: $imageUrl, PublicId: $publicId',
        );

        // Update AuthProvider
        await authProvider.updateUserProfileImage(imageUrl, publicId);

        // Update local state and callback
        if (mounted) {
          widget.onImageUploaded?.call(imageUrl, publicId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorMessage =
            responseData['message'] ?? responseData['error'] ?? 'Upload failed';
        debugPrint('[ProfileImageUpload] Upload failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[ProfileImageUpload] Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _removeImage() async {
    if (!mounted) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (_publicId != null && _publicId!.isNotEmpty) {
        debugPrint('[ProfileImageUpload] Removing image: $_publicId');

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}/api/delete/profile-picture'),
        );

        // Add public_id field
        request.fields['public_id'] = _publicId!;

        // Add authorization header if available
        if (authProvider.userToken != null) {
          request.headers['Authorization'] = 'Bearer ${authProvider.userToken}';
        }

        final response = await request.send().timeout(
          const Duration(seconds: 30),
        );

        final responseBody = await response.stream.bytesToString();
        final responseData = json.decode(responseBody);

        if (response.statusCode == 200 && responseData['success'] == true) {
          debugPrint('[ProfileImageUpload] Image removed successfully');

          // Update AuthProvider to clear image
          if (mounted) {
            await authProvider.updateUserProfileImage('', '');

            setState(() {
              _imageUrl = null;
              _publicId = null;
            });

            // Call callback
            widget.onImageRemoved?.call();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile picture removed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } else {
          throw Exception(responseData['error'] ?? 'Removal failed');
        }
      } else {
        // Just clear local state if no public_id
        if (mounted) {
          await authProvider.updateUserProfileImage('', '');

          setState(() {
            _imageUrl = null;
            _publicId = null;
          });

          widget.onImageRemoved?.call();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture removed!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ProfileImageUpload] Remove error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display only resolved _imageUrl so we never show a previous user's picture (resolution uses widget + AuthProvider correctly)
    final displayImageUrl = _imageUrl;

    return GestureDetector(
      onTap: () {
        SoundSystem.playButtonClick();
        _showImageOptions();
      },
      child: Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: Colors.grey[300],
            backgroundImage: displayImageUrl != null && displayImageUrl.isNotEmpty
                ? NetworkImage(displayImageUrl)
                : null,
            child: (displayImageUrl == null || displayImageUrl.isEmpty)
                ? Icon(
                    Icons.person,
                    size: widget.radius * 0.8,
                    color: Colors.grey[600],
                  )
                : null,
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
                (displayImageUrl != null && displayImageUrl.isNotEmpty) ? Icons.edit : Icons.add,
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
