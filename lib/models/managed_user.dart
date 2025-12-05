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
  String? moduleAccess; // PDH or SOW Builder
  String? moduleRole; // Employee or Manager (depends on moduleAccess)
  String? moduleAccessRole; // Combined field like "PDH - Employee, Skills Heatmap - Manager"
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get name => '$firstName $lastName'.trim();

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
    this.moduleAccess,
    this.moduleRole,
    this.moduleAccessRole,
    this.createdAt,
    this.updatedAt,
  });

  factory ManagedUser.fromFirestore(
    String id,
    Map<String, dynamic> userData,
    Map<String, dynamic> onboardingData,
  ) {
    String firstName = onboardingData['firstName'] ?? '';
    String lastName = onboardingData['lastName'] ?? '';

    if (firstName.isEmpty && lastName.isEmpty) {
      final userName = userData['name'] as String?;
      if (userName != null && userName.isNotEmpty) {
        final nameParts = userName.split(' ');
        if (nameParts.isNotEmpty) {
          firstName = nameParts[0];
        }
        if (nameParts.length > 1) {
          lastName = nameParts.sublist(1).join(' ');
        }
      }
    }

    final onboardingEntity = onboardingData['entity'];
    final userEntity = userData['entity'];
    final String? entityValue;
    if (onboardingEntity is String && onboardingEntity.isNotEmpty) {
      entityValue = onboardingEntity;
    } else if (userEntity is String && userEntity.isNotEmpty) {
      entityValue = userEntity;
    } else {
      entityValue = null;
    }

    // Get moduleAccess and moduleRole from onboarding data
    final onboardingModuleAccess = onboardingData['moduleAccess'];
    final userModuleAccess = userData['moduleAccess'];
    final String? moduleAccessValue;
    if (onboardingModuleAccess is String && onboardingModuleAccess.isNotEmpty) {
      moduleAccessValue = onboardingModuleAccess;
    } else if (userModuleAccess is String && userModuleAccess.isNotEmpty) {
      moduleAccessValue = userModuleAccess;
    } else {
      moduleAccessValue = null;
    }

    final onboardingModuleRole = onboardingData['moduleRole'];
    final userModuleRole = userData['moduleRole'];
    final String? moduleRoleValue;
    if (onboardingModuleRole is String && onboardingModuleRole.isNotEmpty) {
      moduleRoleValue = onboardingModuleRole;
    } else if (userModuleRole is String && userModuleRole.isNotEmpty) {
      moduleRoleValue = userModuleRole;
    } else {
      moduleRoleValue = null;
    }

    final moduleAccessRoleValue = (onboardingData['moduleAccessRole'] as String?)?.isNotEmpty == true
        ? onboardingData['moduleAccessRole'] as String
        : (userData['moduleAccessRole'] as String?)?.isNotEmpty == true
            ? userData['moduleAccessRole'] as String
            : null;

    // Derive moduleAccess from moduleAccessRole if moduleAccess is empty
    final finalModuleAccess = _deriveModuleAccessFromRole(moduleAccessValue, moduleAccessRoleValue);

    return ManagedUser(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: userData['email'] ?? '',
      department: onboardingData['department'] ?? '',
      designation: onboardingData['designation'] ?? '',
      role: userData['role'] ?? 'Staff',
      status: userData['status'] ?? 'Active',
      entity: entityValue,
      moduleAccess: finalModuleAccess,
      moduleRole: moduleRoleValue,
      moduleAccessRole: moduleAccessRoleValue,
    );
  }

  factory ManagedUser.fromApi(Map<String, dynamic> data) {
    final createdAtRaw = data['createdAt'];
    final updatedAtRaw = data['updatedAt'];

    final moduleAccessRaw = (data['moduleAccess'] as String?)?.isNotEmpty == true
        ? data['moduleAccess'] as String
        : null;
    final moduleAccessRoleRaw = (data['moduleAccessRole'] as String?)?.isNotEmpty == true
        ? data['moduleAccessRole'] as String
        : null;

    // Derive moduleAccess from moduleAccessRole if moduleAccess is empty
    final finalModuleAccess = _deriveModuleAccessFromRole(moduleAccessRaw, moduleAccessRoleRaw);

    return ManagedUser(
      id: data['id'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      department: data['department'] ?? '',
      designation: data['designation'] ?? '',
      role: data['role'] ?? 'Staff',
      status: data['status'] ?? 'Active',
      entity: (data['entity'] as String?)?.isNotEmpty == true
          ? data['entity'] as String
          : null,
      moduleAccess: finalModuleAccess,
      moduleRole: (data['moduleRole'] as String?)?.isNotEmpty == true
          ? data['moduleRole'] as String
          : null,
      moduleAccessRole: moduleAccessRoleRaw,
      createdAt: createdAtRaw is String && createdAtRaw.isNotEmpty
          ? DateTime.tryParse(createdAtRaw)
          : null,
      updatedAt: updatedAtRaw is String && updatedAtRaw.isNotEmpty
          ? DateTime.tryParse(updatedAtRaw)
          : null,
    );
  }
}
