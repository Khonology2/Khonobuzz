import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() async {
  print('🔍 TESTING IMAGEKIT PROFILE PICTURE UPLOAD');
  print('=' * 50);
  
  // Test image path
  final imagePath = 'assets/images/Account_User Profile/red_user_profile.png';
  final imageFile = File(imagePath);
  
  if (!await imageFile.exists()) {
    print('❌ Test image not found at: $imagePath');
    return;
  }
  
  print('✅ Test image found: ${imageFile.path}');
  print('📁 Image size: ${await imageFile.length()} bytes');
  
  // Test backend health first
  try {
    final healthResponse = await http.get(
      Uri.parse('http://localhost:5000/health'),
    ).timeout(const Duration(seconds: 5));
    
    if (healthResponse.statusCode == 200) {
      print('✅ Backend is running and healthy');
    } else {
      print('❌ Backend health check failed: ${healthResponse.statusCode}');
      return;
    }
  } catch (e) {
    print('❌ Cannot connect to backend: $e');
    print('💡 Make sure the backend is running on localhost:5000');
    return;
  }
  
  // Test upload endpoint with ImageKit
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:5000/api/upload/profile-picture'),
    );
    
    // Add the image file with proper content type
    final imageBytes = await imageFile.readAsBytes();
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'red_user_profile.png',
      contentType: MediaType.parse('image/png'),
    );
    
    request.files.add(multipartFile);
    
    print('📤 Sending upload request to ImageKit...');
    
    // Send request with timeout
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );
    
    // Get response
    final response = await http.Response.fromStream(streamedResponse);
    
    print('📥 Response status: ${response.statusCode}');
    print('📄 Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      try {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['success'] == true) {
          print('✅ Upload to ImageKit successful!');
          print('🔗 Image URL: ${jsonResponse['secure_url']}');
          print('🆔 File ID: ${jsonResponse['public_id']}');
        } else {
          print('❌ Upload failed: ${jsonResponse['error'] ?? jsonResponse['message']}');
        }
      } catch (e) {
        print('❌ Failed to parse JSON response: $e');
      }
    } else {
      print('❌ Upload failed with status: ${response.statusCode}');
      print('📄 Error response: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Upload error: $e');
  }
  
  print('\n🎯 ImageKit upload test completed!');
  print('=' * 50);
}
