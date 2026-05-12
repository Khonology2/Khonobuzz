import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

Future<void> updateOnboardingUserPartial(
  String uid,
  Map<String, dynamic> onboardingFields,
) async {
  try {
    final response = await http.patch(
      Uri.parse(ApiConfig.onboardingUpdateUserEndpoint(uid)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'onboardingFields': onboardingFields,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user in onboarding: ${response.body}');
    }
    debugPrint('Successfully updated user $uid in onboarding via backend.');
  } catch (e) {
    debugPrint('!!!!!!!! ERROR updating user $uid in onboarding: $e !!!!!!!!!!');
    rethrow;
  }
}

Future<void> syncUserToPDH(
  Map<String, dynamic> userData,
  Map<String, dynamic> onboardingData,
  String uid,
) async {
  try {
    final response = await http.post(
      Uri.parse(ApiConfig.pdhSyncUserEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': uid,
        'userData': userData,
        'onboardingData': onboardingData,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to sync new user to PDH: ${response.body}');
    }
    debugPrint('Successfully synced new user $uid to PDH via backend.');
  } catch (e) {
    debugPrint('!!!!!!!! ERROR syncing new user $uid to PDH: $e !!!!!!!!!!');
    rethrow;
  }
}

Future<void> updatePDHUserPartial(
  String uid,
  Map<String, dynamic> userFields, {
  Map<String, dynamic>? onboardingFields,
}) async {
  try {
    final response = await http.patch(
      Uri.parse(ApiConfig.pdhUpdateUserEndpoint(uid)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userFields': userFields,
        'onboardingFields': onboardingFields,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user in PDH: ${response.body}');
    }
    debugPrint('Successfully updated user $uid in PDH via backend.');
  } catch (e) {
    debugPrint('!!!!!!!! ERROR updating user $uid in PDH: $e !!!!!!!!!!');
    rethrow;
  }
}

Future<void> syncUserToSkillsHeatmap(
  Map<String, dynamic> userData,
  Map<String, dynamic> onboardingData,
  String uid,
) async {
  try {
    final response = await http.post(
      Uri.parse(ApiConfig.skillsHeatmapSyncUserEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': uid,
        'userData': userData,
        'onboardingData': onboardingData,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to sync new user to Skills Heatmap: ${response.body}',
      );
    }
    debugPrint(
      'Successfully synced new user $uid to Skills Heatmap via backend.',
    );
  } catch (e) {
    debugPrint(
      '!!!!!!!! ERROR syncing new user $uid to Skills Heatmap: $e !!!!!!!!!!',
    );
    rethrow;
  }
}

Future<void> updateSkillsHeatmapUserPartial(
  String uid,
  Map<String, dynamic> userFields, {
  Map<String, dynamic>? onboardingFields,
}) async {
  try {
    final response = await http.patch(
      Uri.parse(ApiConfig.skillsHeatmapUpdateUserEndpoint(uid)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userFields': userFields,
        'onboardingFields': onboardingFields,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update user in Skills Heatmap: ${response.body}',
      );
    }
    debugPrint('Successfully updated user $uid in Skills Heatmap via backend.');
  } catch (e) {
    debugPrint(
      '!!!!!!!! ERROR updating user $uid in Skills Heatmap: $e !!!!!!!!!!',
    );
    rethrow;
  }
}
