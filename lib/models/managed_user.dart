import '../utils/user_display_name.dart';

class ManagedUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String department;
  final String designation;
  String role;
  String status;
  String? entity;
  String? manager;
  String? moduleAccess; // PDH or SOW Builder
  String? moduleRole; // Employee, Manager, or Admin (depends on moduleAccess)
  String? moduleAccessRole; // Combined field like "PDH - Employee, Skills Heatmap - Manager"
  String? phoneNumber; // New field for phone number
  String? profilePictureUrl; // New field for profile picture URL
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSignInAt;
  final int loginCount;

  String get name => '$firstName $lastName'.trim();

  /// Shown in lists when [name] is empty (API omitted names or used only alternate keys).
  String get displayName {
    final n = name.trim();
    if (n.isNotEmpty) return n;
    final fromEmail = userDisplayNameFromEmail(email);
    if (fromEmail.isNotEmpty) return fromEmail;
    return email.trim();
  }

  static String? _firstNonEmptyString(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String displayLabelFromUserPayload(Map<String, dynamic> data) {
    final merged = Map<String, dynamic>.from(data);
    merged.putIfAbsent('id', () => merged['id'] ?? '');
    return ManagedUser.fromApi(merged).displayName;
  }

  /// Derives moduleAccess from moduleAccessRole if moduleAccess is empty or incomplete
  static String? _deriveModuleAccessFromRole(String? moduleAccess, String? moduleAccessRole) {
    // If moduleAccess already has values, use it
    if (moduleAccess != null && moduleAccess.trim().isNotEmpty) {
      return moduleAccess;
    }
    
    // If moduleAccessRole is empty, return null
    if (moduleAccessRole == null || moduleAccessRole.trim().isEmpty) {
      return null;
    }
    
    // Extract module names from moduleAccessRole
    final parts = moduleAccessRole.split(',');
    final List<String> moduleNames = [];
    
    for (var part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('PDH')) {
        if (!moduleNames.contains('Personal Development Hub')) {
          moduleNames.add('Personal Development Hub');
        }
      } else if (trimmed.startsWith('Skills Heatmap')) {
        if (!moduleNames.contains('Resource & Capacity Skills Heatmap')) {
          moduleNames.add('Resource & Capacity Skills Heatmap');
        }
      } else if (trimmed.startsWith('Automated Recruitment Workflow')) {
        if (!moduleNames.contains('Automated Recruitment Workflow')) {
          moduleNames.add('Automated Recruitment Workflow');
        }
      } else if (trimmed.startsWith('Proposal & SOW Builder') || trimmed.startsWith('SOW Builder')) {
        if (!moduleNames.contains('Proposal & SOW Builder')) {
          moduleNames.add('Proposal & SOW Builder');
        }
      }
    }
    
    return moduleNames.isEmpty ? null : moduleNames.join(',');
  }

  ManagedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.department,
    required this.designation,
    this.role = 'Staff',
    this.status = 'Active',
    this.entity,
    this.manager,
    this.moduleAccess,
    this.moduleRole,
    this.moduleAccessRole,
    this.phoneNumber,
    this.profilePictureUrl,
    this.createdAt,
    this.updatedAt,
    this.lastSignInAt,
    this.loginCount = 0,
  });

  /// Copy with optional overrides so the updated user can be sorted to the top.
  ManagedUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? department,
    String? designation,
    String? role,
    String? status,
    DateTime? updatedAt,
    String? entity,
    String? manager,
    String? moduleAccess,
    String? moduleRole,
    String? moduleAccessRole,
    String? phoneNumber,
    String? profilePictureUrl,
    DateTime? createdAt,
    DateTime? lastSignInAt,
    int? loginCount,
  }) {
    return ManagedUser(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      status: status ?? this.status,
      entity: entity ?? this.entity,
      manager: manager ?? this.manager,
      moduleAccess: moduleAccess ?? this.moduleAccess,
      moduleRole: moduleRole ?? this.moduleRole,
      moduleAccessRole: moduleAccessRole ?? this.moduleAccessRole,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      loginCount: loginCount ?? this.loginCount,
    );
  }

  static int _parseLoginCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// API may return Active, Inactive, or legacy Pending; the app uses only Active / Inactive.
  static String normalizeAccountStatus(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s == 'active') return 'Active';
    return 'Inactive';
  }

  factory ManagedUser.fromApi(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    final updatedAtRaw = data['updatedAt'];
    final lastSignInAtRaw = data['lastSignInAt'];

    final moduleAccessRaw = (data['moduleAccess'] as String?)?.isNotEmpty == true
        ? data['moduleAccess'] as String
        : null;
    final moduleAccessRoleRaw = (data['moduleAccessRole'] as String?)?.isNotEmpty == true
        ? data['moduleAccessRole'] as String
        : null;

    // Derive moduleAccess from moduleAccessRole if moduleAccess is empty
    final finalModuleAccess = _deriveModuleAccessFromRole(moduleAccessRaw, moduleAccessRoleRaw);

    String parsedFirstName =
        _firstNonEmptyString(data, const ['firstName', 'first_name', 'givenName', 'given_name']) ??
            '';
    String parsedLastName = _firstNonEmptyString(data, const [
          'lastName',
          'last_name',
          'surname',
          'familyName',
          'family_name',
        ]) ??
        '';

    if (parsedFirstName.isEmpty && parsedLastName.isEmpty) {
      final fullName = _firstNonEmptyString(data, const [
            'fullName',
            'full_name',
            'displayName',
            'display_name',
            'name',
          ]) ??
          '';
      if (fullName.isNotEmpty) {
        final parts = fullName.split(RegExp(r'\s+'));
        parsedFirstName = parts.first;
        if (parts.length > 1) {
          parsedLastName = parts.sublist(1).join(' ');
        }
      }
    }

    if (parsedFirstName.isEmpty && parsedLastName.isNotEmpty) {
      final legacyName = (data['name'] ?? '').toString().trim();
      if (legacyName.isNotEmpty && legacyName.toLowerCase() != parsedLastName.toLowerCase()) {
        parsedFirstName = legacyName;
      }
    }

    return ManagedUser(
      id: data['id'] ?? '',
      firstName: parsedFirstName,
      lastName: parsedLastName,
      email: data['email'] ?? '',
      department: data['department'] ?? '',
      designation: data['designation'] ?? '',
      role: data['role'] ?? 'Staff',
      status: normalizeAccountStatus(data['status']?.toString()),
      entity: (data['entity'] as String?)?.isNotEmpty == true
          ? data['entity'] as String
          : null,
      manager: (data['manager'] as String?)?.isNotEmpty == true
          ? data['manager'] as String
          : null,
      moduleAccess: finalModuleAccess,
      moduleRole: (data['moduleRole'] as String?)?.isNotEmpty == true
          ? data['moduleRole'] as String
          : null,
      moduleAccessRole: moduleAccessRoleRaw,
      phoneNumber: data['phone'],
      profilePictureUrl: data['profilePictureUrl'] ?? data['profileImageUrl'],
      createdAt: createdAtRaw is String && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
      updatedAt: updatedAtRaw is String && updatedAtRaw.isNotEmpty
          ? DateTime.tryParse(updatedAtRaw)
          : null,
      lastSignInAt: lastSignInAtRaw is String && lastSignInAtRaw.isNotEmpty
          ? DateTime.tryParse(lastSignInAtRaw)
          : null,
      loginCount: _parseLoginCount(data['loginCount']),
    );
  }
}
