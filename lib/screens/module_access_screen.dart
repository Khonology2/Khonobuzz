import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/managed_user.dart';
import '../utils/pdh_firebase.dart'
    show updatePDHUserPartial, updateSkillsHeatmapUserPartial;
import '../config/api_config.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sound_system.dart';

class ModuleAccessScreen extends StatefulWidget {
  const ModuleAccessScreen({super.key});

  @override
  State<ModuleAccessScreen> createState() => _ModuleAccessScreenState();
}

class _ModuleAccessScreenState extends State<ModuleAccessScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _moduleRoleOptionsPDH = ['Employee', 'Manager', 'Admin'];
  final List<String> _moduleRoleOptionsRecruitment = [
    'Admin',
    'Hiring Manager',
    'Candidate',
  ];
  final List<String> _moduleRoleOptionsSOWBuilder = [
    'Admin',
    'Manager',
    'Finance',
  ];
  final List<String> _moduleRoleOptionsDeliverables = [
    'System admin',
    'Client',
    'Team member',
  ];
  final List<String> _moduleRoleOptionsSkillsHeatmap = [
    'Executive',
    'Delivery Manager',
    'HR',
    'Sales Manager',
    'Ops Manager',
    'System Admin',
  ];
  static const String _notAssignedValue = 'Not Assigned';

  String? expandedUserId;
  String? _updatingUserId;
  Timer? _debounceTimer;
  String _searchQuery = '';

  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = <String>{};

  String _sortOption = 'name';

  List<ManagedUser> get _sortedFilteredUsers {
    final list = List<ManagedUser>.from(_filteredUsers);
    switch (_sortOption) {
      case 'department':
        list.sort((a, b) => a.department.compareTo(b.department));
        break;
      case 'modules_desc':
        list.sort((a, b) {
          final aCount = _moduleCount(a);
          final bCount = _moduleCount(b);
          if (bCount != aCount) return bCount.compareTo(aCount);
          return a.name.compareTo(b.name);
        });
        break;
      case 'name':
      default:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  int _moduleCount(ManagedUser user) {
    if (user.moduleAccess == null || user.moduleAccess!.isEmpty) return 0;
    return user.moduleAccess!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .length;
  }

  final Map<String, String?> _selectedRecruitmentRoles = {};

  final Map<String, String?> _selectedSOWBuilderRoles = {};

  final Map<String, String?> _selectedDeliverablesRoles = {};

  final Map<String, String?> _selectedSkillsHeatmapRoles = {};

  Map<String, Color> get userStatusColors => {
    'Active': Colors.green.shade600,
    'Inactive': Colors.grey.shade600,
    'Pending': Colors.orange.shade500,
  };

  Map<String, Color> get userRoleColors => {
    'Staff': Colors.blue.shade600,
    'Manager': Colors.purple.shade600,
    'Admin': const Color(0xFFC10D00),
  };

  static const Map<String, Color> _moduleDotColors = {
    'Personal Development Hub': Color(0xFFC10D00),
    'Resource & Capacity Skills Heatmap': Color(0xFF0D9488),
    'Automated Recruitment Workflow': Color(0xFF2563EB),
    'Proposal & SOW Builder': Color(0xFFD97706),
    'Deliverables & Sprint Sign-Off Hub': Color(0xFF7C3AED),
  };

  static List<String> get _moduleLegendOrder => [
    'Personal Development Hub',
    'Resource & Capacity Skills Heatmap',
    'Automated Recruitment Workflow',
    'Proposal & SOW Builder',
    'Deliverables & Sprint Sign-Off Hub',
  ];

  String? _canonicalModuleName(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t == 'PDH' || t == 'Personal Development Hub') {
      return 'Personal Development Hub';
    }
    if (t == 'Skills Heatmap' || t == 'Resource & Capacity Skills Heatmap') {
      return 'Resource & Capacity Skills Heatmap';
    }
    if (t == 'Automated Recruitment Workflow') {
      return t;
    }
    if (t == 'SOW Builder' || t == 'Proposal & SOW Builder') {
      return 'Proposal & SOW Builder';
    }
    if (t == 'Deliverables & Sprint Sign-Off Hub') {
      return t;
    }
    return t;
  }

  List<Widget> _buildModuleAccessDots(String? moduleAccess) {
    if (moduleAccess == null || moduleAccess.isEmpty) {
      return [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
          ),
        ),
        const SizedBox(width: 8.0),
        Text(
          'No modules assigned · Tap to assign',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.0,
            fontFamily: 'Poppins',
          ),
        ),
      ];
    }
    final accessList = moduleAccess
        .split(',')
        .map((e) => _canonicalModuleName(e))
        .where((e) => e != null)
        .cast<String>()
        .toList();
    if (accessList.isEmpty) {
      return [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
          ),
        ),
        const SizedBox(width: 8.0),
        Text(
          'No modules assigned · Tap to assign',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.0,
            fontFamily: 'Poppins',
          ),
        ),
      ];
    }
    return accessList.map((name) {
      final color = _moduleDotColors[name] ?? Colors.white54;
      return Tooltip(
        message: name,
        child: Container(
          margin: const EdgeInsets.only(right: 6.0),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<ManagedUser> get _filteredUsers {
    final userProvider = Provider.of<UserProvider>(context);
    final users = userProvider.users;
    final query = _searchQuery.toLowerCase();

    if (query.isEmpty) return users;

    return users.where((user) {
      final moduleAccessList = (user.moduleAccess ?? '')
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();

      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.department.toLowerCase().contains(query) ||
          user.designation.toLowerCase().contains(query) ||
          moduleAccessList.any((access) => access.contains(query)) ||
          (user.moduleRole ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    userProvider.fetchUsers(forceRefresh: true);

    if (userProvider.hasCachedData) {
      userProvider.refreshUsersInBackground();
    }
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  Future<void> _refreshUsers() async {
    SoundSystem.playButtonClick();
    final userProvider = context.read<UserProvider>();
    await userProvider.fetchUsers(forceRefresh: true);
    if (!mounted) return;

    if (userProvider.hasError) {
      SoundSystem.playError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userProvider.errorMessage ?? 'Failed to refresh users.',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'User list refreshed.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        backgroundColor: Color(0xFFC10D00),
      ),
    );
  }

  void _refreshRecruitmentRoleCache(ManagedUser user) {
    if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
      final parts = user.moduleAccessRole!.split(', ');
      for (var part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.startsWith('Automated Recruitment Workflow - ')) {
          final extractedRole = trimmedPart
              .replaceFirst('Automated Recruitment Workflow - ', '')
              .trim();

          final roleLower = extractedRole.toLowerCase();
          for (var option in _moduleRoleOptionsRecruitment) {
            if (option.toLowerCase() == roleLower) {
              _selectedRecruitmentRoles[user.id] = option;
              return;
            }
          }

          if (extractedRole.isNotEmpty) {
            _selectedRecruitmentRoles[user.id] = extractedRole;
          }
          return;
        }
      }
    }

    _selectedRecruitmentRoles[user.id] = _notAssignedValue;
  }

  void _refreshSOWBuilderRoleCache(ManagedUser user) {
    if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
      final parts = user.moduleAccessRole!.split(', ');
      for (var part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.startsWith('Proposal & SOW Builder - ')) {
          final extractedRole = trimmedPart
              .replaceFirst('Proposal & SOW Builder - ', '')
              .trim();

          final roleLower = extractedRole.toLowerCase();
          for (var option in _moduleRoleOptionsSOWBuilder) {
            if (option.toLowerCase() == roleLower) {
              _selectedSOWBuilderRoles[user.id] = option;
              return;
            }
          }

          if (extractedRole.isNotEmpty) {
            _selectedSOWBuilderRoles[user.id] = extractedRole;
          }
          return;
        }
      }
    }

    _selectedSOWBuilderRoles[user.id] = _notAssignedValue;
  }

  void _refreshDeliverablesRoleCache(ManagedUser user) {
    if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
      final parts = user.moduleAccessRole!.split(', ');
      for (var part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.startsWith('Deliverables & Sprint Sign-Off Hub - ')) {
          final extractedRole = trimmedPart
              .replaceFirst('Deliverables & Sprint Sign-Off Hub - ', '')
              .trim();

          final roleLower = extractedRole.toLowerCase();
          for (var option in _moduleRoleOptionsDeliverables) {
            if (option.toLowerCase() == roleLower) {
              _selectedDeliverablesRoles[user.id] = option;
              return;
            }
          }

          if (extractedRole.isNotEmpty) {
            _selectedDeliverablesRoles[user.id] = extractedRole;
          }
          return;
        }
      }
    }

    _selectedDeliverablesRoles[user.id] = _notAssignedValue;
  }

  void _refreshSkillsHeatmapRoleCache(ManagedUser user) {
    if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
      final parts = user.moduleAccessRole!.split(', ');
      for (var part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.startsWith('Skills Heatmap - ')) {
          final extractedRole = trimmedPart
              .replaceFirst('Skills Heatmap - ', '')
              .trim();

          final roleLower = extractedRole.toLowerCase();
          for (var option in _moduleRoleOptionsSkillsHeatmap) {
            if (option.toLowerCase() == roleLower) {
              _selectedSkillsHeatmapRoles[user.id] = option;
              return;
            }
          }

          if (extractedRole.isNotEmpty && extractedRole != 'Manager') {
            _selectedSkillsHeatmapRoles[user.id] = extractedRole;
          } else if (extractedRole == 'Manager') {
            // Default to first option for existing Manager roles
            _selectedSkillsHeatmapRoles[user.id] =
                _moduleRoleOptionsSkillsHeatmap.first;
          }
          return;
        }
      }
    }

    _selectedSkillsHeatmapRoles[user.id] = _notAssignedValue;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateModuleAccessList(
    ManagedUser user,
    bool pdhSelected,
    bool skillsHeatmapSelected,
    bool recruitmentSelected,
    bool sowBuilderSelected,
    bool deliverablesSelected,
  ) {
    List<String> accessList = [];
    if (pdhSelected) accessList.add('Personal Development Hub');
    if (skillsHeatmapSelected) {
      accessList.add('Resource & Capacity Skills Heatmap');
    }
    if (recruitmentSelected) accessList.add('Automated Recruitment Workflow');
    if (sowBuilderSelected) accessList.add('Proposal & SOW Builder');
    if (deliverablesSelected) {
      accessList.add('Deliverables & Sprint Sign-Off Hub');
    }

    user.moduleAccess = accessList.isEmpty ? null : accessList.join(',');
  }

  Future<void> _updateUserModuleAccess(
    ManagedUser user,
    bool pdhSelected,
    bool skillsHeatmapSelected,
    bool recruitmentSelected,
    bool sowBuilderSelected,
    bool deliverablesSelected,
    String? newModuleRole,
    String? newRecruitmentRole,
    String? newSOWBuilderRole,
    String? newDeliverablesRole,
    String? newSkillsHeatmapRole,
  ) async {
    final adminEmail = context.read<AuthProvider>().userEmail?.trim() ?? '';
    setState(() {
      _updatingUserId = user.id;
    });

    List<String> accessList = [];
    if (pdhSelected) accessList.add('Personal Development Hub');
    if (skillsHeatmapSelected) {
      accessList.add('Resource & Capacity Skills Heatmap');
    }
    if (recruitmentSelected) accessList.add('Automated Recruitment Workflow');
    if (sowBuilderSelected) accessList.add('Proposal & SOW Builder');
    if (deliverablesSelected) {
      accessList.add('Deliverables & Sprint Sign-Off Hub');
    }

    final sanitizedModuleAccess = accessList.isEmpty
        ? ''
        : accessList.join(',');

    String sanitizedModuleRole = '';
    String sanitizedRecruitmentRole = '';

    if (pdhSelected) {
      sanitizedModuleRole =
          (newModuleRole != null &&
              newModuleRole.trim().isNotEmpty &&
              newModuleRole != _notAssignedValue)
          ? newModuleRole.trim()
          : '';
    }

    if (recruitmentSelected) {
      sanitizedRecruitmentRole =
          (newRecruitmentRole != null &&
              newRecruitmentRole.trim().isNotEmpty &&
              newRecruitmentRole != _notAssignedValue)
          ? newRecruitmentRole.trim()
          : '';
    }

    String sanitizedSOWBuilderRole = '';
    if (sowBuilderSelected) {
      sanitizedSOWBuilderRole =
          (newSOWBuilderRole != null &&
              newSOWBuilderRole.trim().isNotEmpty &&
              newSOWBuilderRole != _notAssignedValue)
          ? newSOWBuilderRole.trim()
          : '';
    }

    String sanitizedDeliverablesRole = '';
    if (deliverablesSelected) {
      sanitizedDeliverablesRole =
          (newDeliverablesRole != null &&
              newDeliverablesRole.trim().isNotEmpty &&
              newDeliverablesRole != _notAssignedValue)
          ? newDeliverablesRole.trim()
          : '';
    }

    String sanitizedSkillsHeatmapRole = '';
    if (skillsHeatmapSelected) {
      sanitizedSkillsHeatmapRole =
          (newSkillsHeatmapRole != null &&
              newSkillsHeatmapRole.trim().isNotEmpty &&
              newSkillsHeatmapRole != _notAssignedValue)
          ? newSkillsHeatmapRole.trim()
          : _moduleRoleOptionsSkillsHeatmap.first; // Default to first option
    }

    List<String> combinedParts = [];
    if (pdhSelected && sanitizedModuleRole.isNotEmpty) {
      combinedParts.add('PDH - $sanitizedModuleRole');
    } else if (pdhSelected) {
      combinedParts.add('PDH');
    }
    if (skillsHeatmapSelected) {
      combinedParts.add('Skills Heatmap - $sanitizedSkillsHeatmapRole');
    }
    if (recruitmentSelected && sanitizedRecruitmentRole.isNotEmpty) {
      combinedParts.add(
        'Automated Recruitment Workflow - $sanitizedRecruitmentRole',
      );
    } else if (recruitmentSelected) {
      combinedParts.add('Automated Recruitment Workflow');
    }
    if (sowBuilderSelected && sanitizedSOWBuilderRole.isNotEmpty) {
      combinedParts.add('Proposal & SOW Builder - $sanitizedSOWBuilderRole');
    } else if (sowBuilderSelected) {
      combinedParts.add('Proposal & SOW Builder');
    }
    if (deliverablesSelected && sanitizedDeliverablesRole.isNotEmpty) {
      combinedParts.add(
        'Deliverables & Sprint Sign-Off Hub - $sanitizedDeliverablesRole',
      );
    } else if (deliverablesSelected) {
      combinedParts.add('Deliverables & Sprint Sign-Off Hub');
    }

    String combinedModuleAccess = combinedParts.isEmpty
        ? ''
        : combinedParts.join(', ');

    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(user.id)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': user.role,
          'status': user.status,
          'moduleAccess': sanitizedModuleAccess,
          'moduleRole': sanitizedModuleRole,
          'moduleAccessRole': combinedModuleAccess,
          'regenerateToken': true,
          if (adminEmail.isNotEmpty) 'adminApproved': adminEmail,
        }),
      );

      final decodedResp = jsonDecode(response.body) as Map<String, dynamic>?;
      if (response.statusCode != 200 || decodedResp == null) {
        throw Exception(
          'Failed to update user ${user.id}: ${response.statusCode}',
        );
      }

      final backendUser = decodedResp['user'] as Map<String, dynamic>?;
      final updatedModuleAccess = backendUser != null
          ? (backendUser['moduleAccess'] as String?)?.isNotEmpty == true
                ? backendUser['moduleAccess'] as String
                : null
          : (sanitizedModuleAccess.isEmpty ? null : sanitizedModuleAccess);

      final updatedModuleRole = backendUser != null
          ? (backendUser['moduleRole'] as String?)?.isNotEmpty == true
                ? backendUser['moduleRole'] as String
                : null
          : (sanitizedModuleRole.isEmpty ? null : sanitizedModuleRole);

      final updatedModuleAccessRole = backendUser != null
          ? (backendUser['moduleAccessRole'] as String?)?.isNotEmpty == true
                ? backendUser['moduleAccessRole'] as String
                : null
          : (combinedModuleAccess.isEmpty ? null : combinedModuleAccess);

      setState(() {
        user.moduleAccess = updatedModuleAccess;
        user.moduleRole = updatedModuleRole;
        user.moduleAccessRole = updatedModuleAccessRole;

        if (updatedModuleAccessRole != null &&
            updatedModuleAccessRole.isNotEmpty) {
          final parts = updatedModuleAccessRole.split(', ');
          for (var part in parts) {
            final trimmedPart = part.trim();
            if (trimmedPart.startsWith('Automated Recruitment Workflow - ')) {
              final extractedRole = trimmedPart
                  .replaceFirst('Automated Recruitment Workflow - ', '')
                  .trim();

              final roleLower = extractedRole.toLowerCase();
              for (var option in _moduleRoleOptionsRecruitment) {
                if (option.toLowerCase() == roleLower) {
                  _selectedRecruitmentRoles[user.id] = option;
                  break;
                }
              }
              break;
            }
          }
        } else if (!recruitmentSelected) {
          _selectedRecruitmentRoles[user.id] = _notAssignedValue;
        }

        if (updatedModuleAccessRole != null &&
            updatedModuleAccessRole.isNotEmpty) {
          final parts = updatedModuleAccessRole.split(', ');
          for (var part in parts) {
            final trimmedPart = part.trim();
            if (trimmedPart.startsWith('Proposal & SOW Builder - ')) {
              final extractedRole = trimmedPart
                  .replaceFirst('Proposal & SOW Builder - ', '')
                  .trim();

              final roleLower = extractedRole.toLowerCase();
              for (var option in _moduleRoleOptionsSOWBuilder) {
                if (option.toLowerCase() == roleLower) {
                  _selectedSOWBuilderRoles[user.id] = option;
                  break;
                }
              }
              break;
            }
          }
        } else if (!sowBuilderSelected) {
          _selectedSOWBuilderRoles[user.id] = _notAssignedValue;
        }

        if (updatedModuleAccessRole != null &&
            updatedModuleAccessRole.isNotEmpty) {
          final parts = updatedModuleAccessRole.split(', ');
          for (var part in parts) {
            final trimmedPart = part.trim();
            if (trimmedPart.startsWith(
              'Deliverables & Sprint Sign-Off Hub - ',
            )) {
              final extractedRole = trimmedPart
                  .replaceFirst('Deliverables & Sprint Sign-Off Hub - ', '')
                  .trim();

              final roleLower = extractedRole.toLowerCase();
              for (var option in _moduleRoleOptionsDeliverables) {
                if (option.toLowerCase() == roleLower) {
                  _selectedDeliverablesRoles[user.id] = option;
                  break;
                }
              }
              break;
            }
          }
        } else if (!deliverablesSelected) {
          _selectedDeliverablesRoles[user.id] = _notAssignedValue;
        }
      });

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.updateUser(user);
      }

      final adminField = adminEmail.isNotEmpty
          ? {
              'admin': {'approved': adminEmail},
            }
          : null;

      try {
        await updatePDHUserPartial(
          user.id,
          {
            'moduleAccess': updatedModuleAccess,
            'moduleRole': updatedModuleRole,
            'moduleAccessRole': updatedModuleAccessRole,
            if (adminField != null) ...adminField,
          },
          onboardingFields: {
            'moduleAccess': updatedModuleAccess,
            'moduleRole': updatedModuleRole,
            'moduleAccessRole': updatedModuleAccessRole,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('PDH sync failed for module access update: $e');
        if (mounted) {
          SoundSystem.playError();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Module access updated, but failed to sync with PDH.',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      try {
        await updateSkillsHeatmapUserPartial(
          user.id,
          {
            'moduleAccess': updatedModuleAccess,
            'moduleRole': updatedModuleRole,
            'moduleAccessRole': updatedModuleAccessRole,
            if (adminField != null) ...adminField,
          },
          onboardingFields: {
            'moduleAccess': updatedModuleAccess,
            'moduleRole': updatedModuleRole,
            'moduleAccessRole': updatedModuleAccessRole,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('Skills Heatmap sync failed for module access update: $e');
      }

      if (mounted) {
        SoundSystem.playSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Module access updated for ${user.name}.',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFFC10D00),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SoundSystem.playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update module access. Please try again.',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      setState(() {
        _updatingUserId = null;
      });
    }
  }

  void _showBulkModuleAccessDialog() {
    if (_selectedUserIds.isEmpty) return;
    SoundSystem.playButtonClick();

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool pdhSelected = false;
        bool skillsHeatmapSelected = false;
        bool recruitmentSelected = false;
        bool sowBuilderSelected = false;
        bool deliverablesSelected = false;
        String? selectedModuleRole = _notAssignedValue;
        String? selectedRecruitmentRole = _notAssignedValue;
        String? selectedSOWBuilderRole = _notAssignedValue;
        String? selectedDeliverablesRole = _notAssignedValue;
        String? selectedSkillsHeatmapRole = _notAssignedValue;
        bool isUpdating = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C3E50),
              title: const Text(
                'Update Module Access',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: CheckboxListTile(
                              title: const Text(
                                'Personal Development Hub',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              value: pdhSelected,
                              activeColor: const Color(0xFFC10D00),
                              checkColor: Colors.white,
                              onChanged: (bool? value) {
                                SoundSystem.playButtonClick();
                                setStateDialog(() {
                                  pdhSelected = value ?? false;
                                  if (!pdhSelected) {
                                    selectedModuleRole = _notAssignedValue;
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: pdhSelected
                                  ? const Color(0xFF2C3E50)
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: pdhSelected
                                    ? selectedModuleRole
                                    : _notAssignedValue,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF2C3E50),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white70,
                                ),
                                hint: const Text(
                                  'Module Role',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                style: TextStyle(
                                  color: pdhSelected
                                      ? Colors.white
                                      : Colors.white54,
                                  fontFamily: 'Poppins',
                                ),
                                onChanged: pdhSelected
                                    ? (value) {
                                        SoundSystem.playButtonClick();
                                        setStateDialog(() {
                                          selectedModuleRole = value;
                                        });
                                      }
                                    : null,
                                items: <DropdownMenuItem<String?>>[
                                  DropdownMenuItem<String?>(
                                    value: _notAssignedValue,
                                    child: Text(_notAssignedValue),
                                  ),
                                  ..._moduleRoleOptionsPDH.map(
                                    (option) => DropdownMenuItem<String?>(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: CheckboxListTile(
                              title: const Text(
                                'Resource & Capacity Skills Heatmap',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              value: skillsHeatmapSelected,
                              activeColor: const Color(0xFFC10D00),
                              checkColor: Colors.white,
                              onChanged: (bool? value) {
                                SoundSystem.playButtonClick();
                                setStateDialog(() {
                                  skillsHeatmapSelected = value ?? false;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: skillsHeatmapSelected
                                  ? const Color(0xFF2C3E50)
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: skillsHeatmapSelected
                                    ? selectedSkillsHeatmapRole
                                    : _notAssignedValue,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF2C3E50),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white70,
                                ),
                                hint: const Text(
                                  'Module Role',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                style: TextStyle(
                                  color: skillsHeatmapSelected
                                      ? Colors.white
                                      : Colors.white54,
                                  fontFamily: 'Poppins',
                                ),
                                onChanged: skillsHeatmapSelected
                                    ? (value) {
                                        SoundSystem.playButtonClick();
                                        setStateDialog(() {
                                          selectedSkillsHeatmapRole = value;
                                        });
                                      }
                                    : null,
                                items: <DropdownMenuItem<String?>>[
                                  if (!skillsHeatmapSelected)
                                    DropdownMenuItem<String?>(
                                      value: _notAssignedValue,
                                      child: Text(_notAssignedValue),
                                    ),
                                  ..._moduleRoleOptionsSkillsHeatmap.map(
                                    (option) => DropdownMenuItem<String?>(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: CheckboxListTile(
                              title: const Text(
                                'Automated Recruitment Workflow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              value: recruitmentSelected,
                              activeColor: const Color(0xFFC10D00),
                              checkColor: Colors.white,
                              onChanged: (bool? value) {
                                SoundSystem.playButtonClick();
                                setStateDialog(() {
                                  recruitmentSelected = value ?? false;
                                  if (!recruitmentSelected) {
                                    selectedRecruitmentRole = _notAssignedValue;
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: recruitmentSelected
                                  ? const Color(0xFF2C3E50)
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: recruitmentSelected
                                    ? selectedRecruitmentRole
                                    : _notAssignedValue,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF2C3E50),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white70,
                                ),
                                hint: const Text(
                                  'Module Role',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                style: TextStyle(
                                  color: recruitmentSelected
                                      ? Colors.white
                                      : Colors.white54,
                                  fontFamily: 'Poppins',
                                ),
                                onChanged: recruitmentSelected
                                    ? (value) {
                                        SoundSystem.playButtonClick();
                                        setStateDialog(() {
                                          selectedRecruitmentRole = value;
                                        });
                                      }
                                    : null,
                                items: <DropdownMenuItem<String?>>[
                                  DropdownMenuItem<String?>(
                                    value: _notAssignedValue,
                                    child: Text(_notAssignedValue),
                                  ),
                                  ..._moduleRoleOptionsRecruitment.map(
                                    (option) => DropdownMenuItem<String?>(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: CheckboxListTile(
                              title: const Text(
                                'Proposal & SOW Builder',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              value: sowBuilderSelected,
                              activeColor: const Color(0xFFC10D00),
                              checkColor: Colors.white,
                              onChanged: (bool? value) {
                                SoundSystem.playButtonClick();
                                setStateDialog(() {
                                  sowBuilderSelected = value ?? false;
                                  if (!sowBuilderSelected) {
                                    selectedSOWBuilderRole = _notAssignedValue;
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: sowBuilderSelected
                                  ? const Color(0xFF2C3E50)
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: sowBuilderSelected
                                    ? selectedSOWBuilderRole
                                    : _notAssignedValue,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF2C3E50),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white70,
                                ),
                                hint: const Text(
                                  'Module Role',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                style: TextStyle(
                                  color: sowBuilderSelected
                                      ? Colors.white
                                      : Colors.white54,
                                  fontFamily: 'Poppins',
                                ),
                                onChanged: sowBuilderSelected
                                    ? (value) {
                                        SoundSystem.playButtonClick();
                                        setStateDialog(() {
                                          selectedSOWBuilderRole = value;
                                        });
                                      }
                                    : null,
                                items: <DropdownMenuItem<String?>>[
                                  DropdownMenuItem<String?>(
                                    value: _notAssignedValue,
                                    child: Text(_notAssignedValue),
                                  ),
                                  ..._moduleRoleOptionsSOWBuilder.map(
                                    (option) => DropdownMenuItem<String?>(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C3E50),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                'Deliverables & Sprint Sign-Off Hub',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              value: deliverablesSelected,
                              activeColor: const Color(0xFFC10D00),
                              checkColor: Colors.white,
                              onChanged: (bool? value) {
                                SoundSystem.playButtonClick();
                                setStateDialog(() {
                                  deliverablesSelected = value ?? false;
                                  if (!deliverablesSelected) {
                                    selectedDeliverablesRole =
                                        _notAssignedValue;
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 8.0,
                              ),
                              decoration: BoxDecoration(
                                color: deliverablesSelected
                                    ? const Color(0xFF2C3E50)
                                    : const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: deliverablesSelected
                                      ? selectedDeliverablesRole
                                      : _notAssignedValue,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2C3E50),
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white70,
                                  ),
                                  hint: const Text(
                                    'Module Role',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: deliverablesSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontFamily: 'Poppins',
                                  ),
                                  onChanged: deliverablesSelected
                                      ? (value) {
                                          SoundSystem.playButtonClick();
                                          setStateDialog(() {
                                            selectedDeliverablesRole = value;
                                          });
                                        }
                                      : null,
                                  items: <DropdownMenuItem<String?>>[
                                    DropdownMenuItem<String?>(
                                      value: _notAssignedValue,
                                      child: Text(_notAssignedValue),
                                    ),
                                    ..._moduleRoleOptionsDeliverables.map(
                                      (option) => DropdownMenuItem<String?>(
                                        value: option,
                                        child: Text(option),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating
                      ? null
                      : () {
                          SoundSystem.playButtonClick();
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          SoundSystem.playButtonClick();
                          setStateDialog(() {
                            isUpdating = true;
                          });

                          try {
                            final userProvider = Provider.of<UserProvider>(
                              context,
                              listen: false,
                            );
                            final selectedUsers = userProvider.users
                                .where(
                                  (user) => _selectedUserIds.contains(user.id),
                                )
                                .toList();

                            for (final user in selectedUsers) {
                              await _updateUserModuleAccess(
                                user,
                                pdhSelected,
                                skillsHeatmapSelected,
                                recruitmentSelected,
                                sowBuilderSelected,
                                deliverablesSelected,
                                selectedModuleRole,
                                selectedRecruitmentRole,
                                selectedSOWBuilderRole,
                                selectedDeliverablesRole,
                                selectedSkillsHeatmapRole,
                              );
                            }

                            if (mounted) {
                              setState(() {
                                _isSelectionMode = false;
                                _selectedUserIds.clear();
                              });
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setStateDialog(() {
                                isUpdating = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(45.0),
                    ),
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Update Selected Users',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _isSelectionMode && _selectedUserIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedUserIds.length} user(s) selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            SoundSystem.playButtonClick();
                            setState(() {
                              _isSelectionMode = false;
                              _selectedUserIds.clear();
                            });
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        TextButton(
                          onPressed: () {
                            SoundSystem.playButtonClick();
                            setState(() {
                              final allIds = _filteredUsers
                                  .map((u) => u.id)
                                  .toSet();
                              if (_selectedUserIds.length == allIds.length) {
                                _selectedUserIds.clear();
                                _isSelectionMode = false;
                              } else {
                                _selectedUserIds
                                  ..clear()
                                  ..addAll(allIds);
                                _isSelectionMode = _selectedUserIds.isNotEmpty;
                              }
                            });
                          },
                          child: const Text(
                            'Select all',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () {
                            SoundSystem.playButtonClick();
                            _showBulkModuleAccessDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC10D00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(45.0),
                            ),
                          ),
                          child: const Text(
                            'Update Access',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/nathi_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll<Color>(Colors.white),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16.0),
                        _buildSearch(),
                        const SizedBox(height: 16.0),
                        _buildUserList(),
                        const SizedBox(height: 24.0),
                        _buildModuleLegend(),
                        const SizedBox(height: 24.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final userProvider = context.watch<UserProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Module Access',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh users',
              onPressed: userProvider.isLoading ? null : _refreshUsers,
              icon: userProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFC10D00),
                      ),
                    )
                  : const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          'Assign module access and roles to manage user permissions.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14.0,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search users',
        hintStyle: const TextStyle(
          color: Colors.white54,
          fontFamily: 'Poppins',
        ),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () {
            SoundSystem.playButtonClick();
            setState(() {
              _searchController.clear();
              _searchQuery = '';
            });
          },
        ),
        filled: true,
        fillColor: const Color(0x801F2840),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
      ),
      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(5, (_) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0x801F2840),
              borderRadius: BorderRadius.circular(16.0),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 140,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        height: 12,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Row(
                        children: List.generate(
                          4,
                          (_) => Container(
                            margin: const EdgeInsets.only(right: 6.0),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUserList() {
    final userProvider = Provider.of<UserProvider>(context);

    // Clear expandedUserId if the expanded user no longer exists
    if (expandedUserId != null && mounted) {
      final userExists = userProvider.users.any((u) => u.id == expandedUserId);
      if (!userExists) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              expandedUserId = null;
            });
          }
        });
      }
    }

    if (userProvider.isLoading && userProvider.users.isEmpty) {
      return _buildLoadingSkeleton();
    }

    if (userProvider.hasError && userProvider.users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16.0),
              Text(
                userProvider.errorMessage ??
                    'Failed to load users. The server may be waking up.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 24.0),
              FilledButton.icon(
                onPressed: () {
                  SoundSystem.playButtonClick();
                  userProvider.fetchUsers(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSortBar(),
        const SizedBox(height: 12.0),
        ..._sortedFilteredUsers.map((user) {
          final isExpanded = expandedUserId == user.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              children: [
                _buildUserRow(user, isExpanded),
                if (isExpanded) _buildModuleAccessPanel(user),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSortBar() {
    return Row(
      children: [
        Text(
          'Sort by:',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.0,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _sortChip('Name', 'name'),
                const SizedBox(width: 6.0),
                _sortChip('Department', 'department'),
                const SizedBox(width: 6.0),
                _sortChip('Most modules', 'modules_desc'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sortChip(String label, String value) {
    final isSelected = _sortOption == value;
    return GestureDetector(
      onTap: () {
        SoundSystem.playButtonClick();
        setState(() => _sortOption = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC10D00).withValues(alpha: 0.3)
              : const Color(0x801F2840),
          borderRadius: BorderRadius.circular(20.0),
          border: isSelected
              ? Border.all(color: const Color(0xFFC10D00), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(ManagedUser user) {
    final url = user.profilePictureUrl;
    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white24,
        backgroundImage: NetworkImage(url.trim()),
        onBackgroundImageError: (_, __) {},
      );
    }
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white24,
      child: Icon(Icons.person, size: 24, color: Colors.white54),
    );
  }

  Widget _buildUserRow(ManagedUser user, bool isExpanded) {
    final moduleAccessDots = _buildModuleAccessDots(user.moduleAccess);
    final isSelected = _selectedUserIds.contains(user.id);
    return GestureDetector(
      onLongPress: () {
        SoundSystem.playButtonClick();
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedUserIds.add(user.id);
            expandedUserId = null;
          });
        }
      },
      onTap: () {
        SoundSystem.playButtonClick();
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedUserIds.remove(user.id);
              if (_selectedUserIds.isEmpty) {
                _isSelectionMode = false;
              }
            } else {
              _selectedUserIds.add(user.id);
            }
          });
        } else {
          setState(() {
            if (!isExpanded) {
              expandedUserId = user.id;
              _refreshRecruitmentRoleCache(user);
              _refreshSOWBuilderRoleCache(user);
              _refreshDeliverablesRoleCache(user);
              _refreshSkillsHeatmapRoleCache(user);
            } else {
              expandedUserId = null;
            }
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0x80C10D00) : const Color(0x801F2840),
          borderRadius: BorderRadius.circular(16.0),
          border: isSelected
              ? Border.all(color: const Color(0xFFC10D00), width: 2.0)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (_isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      SoundSystem.playButtonClick();
                      setState(() {
                        if (value == true) {
                          _selectedUserIds.add(user.id);
                        } else {
                          _selectedUserIds.remove(user.id);
                          if (_selectedUserIds.isEmpty) {
                            _isSelectionMode = false;
                          }
                        }
                      });
                    },
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                  ),
                  const SizedBox(width: 8.0),
                ],
                Expanded(
                  child: Row(
                    children: [
                      _buildUserAvatar(user),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                fontFamily: 'Poppins',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.0,
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
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user.designation,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.0,
                          fontFamily: 'Poppins',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        user.department,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.0,
                          fontFamily: 'Poppins',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                if (!_isSelectionMode)
                  Transform.rotate(
                    angle: isExpanded ? 3.14 : 0,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 28,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Text(
                  'Modules:',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.0,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(width: 8.0),
                Wrap(spacing: 2.0, runSpacing: 4.0, children: moduleAccessDots),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0x801F2840),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Module legend',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 10.0),
          Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            children: _moduleLegendOrder.map((name) {
              final color = _moduleDotColors[name] ?? Colors.white54;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.0,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleAccessPanel(ManagedUser user) {
    List<String> selectedModuleAccessList = [];
    if (user.moduleAccess != null && user.moduleAccess!.isNotEmpty) {
      selectedModuleAccessList = user.moduleAccess!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    bool pdhSelected =
        selectedModuleAccessList.contains('Personal Development Hub') ||
        selectedModuleAccessList.contains('PDH');
    bool skillsHeatmapSelected =
        selectedModuleAccessList.contains(
          'Resource & Capacity Skills Heatmap',
        ) ||
        selectedModuleAccessList.contains('Skills Heatmap');
    bool recruitmentSelected = selectedModuleAccessList.contains(
      'Automated Recruitment Workflow',
    );
    bool sowBuilderSelected =
        selectedModuleAccessList.contains('Proposal & SOW Builder') ||
        selectedModuleAccessList.contains('SOW Builder');
    bool deliverablesSelected = selectedModuleAccessList.contains(
      'Deliverables & Sprint Sign-Off Hub',
    );

    String? selectedModuleRole =
        (user.moduleRole == null || user.moduleRole!.isEmpty)
        ? _notAssignedValue
        : user.moduleRole;

    String? selectedRecruitmentRole = _selectedRecruitmentRoles[user.id];

    if (selectedRecruitmentRole == null) {
      selectedRecruitmentRole = _notAssignedValue;
      if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
        final parts = user.moduleAccessRole!.split(', ');
        for (var part in parts) {
          final trimmedPart = part.trim();
          if (trimmedPart.startsWith('Automated Recruitment Workflow - ')) {
            final extractedRole = trimmedPart
                .replaceFirst('Automated Recruitment Workflow - ', '')
                .trim();

            final roleLower = extractedRole.toLowerCase();
            for (var option in _moduleRoleOptionsRecruitment) {
              if (option.toLowerCase() == roleLower) {
                selectedRecruitmentRole = option;
                break;
              }
            }

            if (selectedRecruitmentRole == _notAssignedValue &&
                extractedRole.isNotEmpty) {
              selectedRecruitmentRole = extractedRole;
            }
            break;
          }
        }
      }

      _selectedRecruitmentRoles[user.id] = selectedRecruitmentRole;
    }

    String? selectedSOWBuilderRole = _selectedSOWBuilderRoles[user.id];

    if (selectedSOWBuilderRole == null) {
      selectedSOWBuilderRole = _notAssignedValue;
      if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
        final parts = user.moduleAccessRole!.split(', ');
        for (var part in parts) {
          final trimmedPart = part.trim();
          if (trimmedPart.startsWith('Proposal & SOW Builder - ')) {
            final extractedRole = trimmedPart
                .replaceFirst('Proposal & SOW Builder - ', '')
                .trim();

            final roleLower = extractedRole.toLowerCase();
            for (var option in _moduleRoleOptionsSOWBuilder) {
              if (option.toLowerCase() == roleLower) {
                selectedSOWBuilderRole = option;
                break;
              }
            }

            if (selectedSOWBuilderRole == _notAssignedValue &&
                extractedRole.isNotEmpty) {
              selectedSOWBuilderRole = extractedRole;
            }
            break;
          }
        }
      }

      _selectedSOWBuilderRoles[user.id] = selectedSOWBuilderRole;
    }

    String? selectedDeliverablesRole = _selectedDeliverablesRoles[user.id];

    if (selectedDeliverablesRole == null) {
      selectedDeliverablesRole = _notAssignedValue;
      if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
        final parts = user.moduleAccessRole!.split(', ');
        for (var part in parts) {
          final trimmedPart = part.trim();
          if (trimmedPart.startsWith('Deliverables & Sprint Sign-Off Hub - ')) {
            final extractedRole = trimmedPart
                .replaceFirst('Deliverables & Sprint Sign-Off Hub - ', '')
                .trim();

            final roleLower = extractedRole.toLowerCase();
            for (var option in _moduleRoleOptionsDeliverables) {
              if (option.toLowerCase() == roleLower) {
                selectedDeliverablesRole = option;
                break;
              }
            }

            if (selectedDeliverablesRole == _notAssignedValue &&
                extractedRole.isNotEmpty) {
              selectedDeliverablesRole = extractedRole;
            }
            break;
          }
        }
      }

      _selectedDeliverablesRoles[user.id] = selectedDeliverablesRole;
    }

    String? selectedSkillsHeatmapRole = _selectedSkillsHeatmapRoles[user.id];

    if (selectedSkillsHeatmapRole == null) {
      selectedSkillsHeatmapRole = _notAssignedValue;
      if (user.moduleAccessRole != null && user.moduleAccessRole!.isNotEmpty) {
        final parts = user.moduleAccessRole!.split(', ');
        for (var part in parts) {
          final trimmedPart = part.trim();
          if (trimmedPart.startsWith('Skills Heatmap - ')) {
            final extractedRole = trimmedPart
                .replaceFirst('Skills Heatmap - ', '')
                .trim();

            final roleLower = extractedRole.toLowerCase();
            for (var option in _moduleRoleOptionsSkillsHeatmap) {
              if (option.toLowerCase() == roleLower) {
                selectedSkillsHeatmapRole = option;
                break;
              }
            }

            if (selectedSkillsHeatmapRole == _notAssignedValue &&
                extractedRole.isNotEmpty) {
              selectedSkillsHeatmapRole = extractedRole;
            }
            break;
          }
        }
      }

      _selectedSkillsHeatmapRoles[user.id] = selectedSkillsHeatmapRole;
    }

    final roleSummary = <String>[];
    if (pdhSelected) {
      roleSummary.add('PDH: ${selectedModuleRole ?? _notAssignedValue}');
    }
    if (skillsHeatmapSelected) {
      roleSummary.add(
        'Skills Heatmap: ${selectedSkillsHeatmapRole ?? _notAssignedValue}',
      );
    }
    if (recruitmentSelected) {
      roleSummary.add(
        'Recruitment: ${selectedRecruitmentRole ?? _notAssignedValue}',
      );
    }
    if (sowBuilderSelected) {
      roleSummary.add(
        'SOW Builder: ${selectedSOWBuilderRole ?? _notAssignedValue}',
      );
    }
    if (deliverablesSelected) {
      roleSummary.add(
        'Deliverables: ${selectedDeliverablesRole ?? _notAssignedValue}',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0x801A1A1A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        children: [
          if (roleSummary.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 6.0,
                children: [
                  Text(
                    'Current roles:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12.0,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  ...roleSummary.map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.0,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4.0),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'Personal Development Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    value: pdhSelected,
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      SoundSystem.playButtonClick();
                      setState(() {
                        pdhSelected = value ?? false;
                        _updateModuleAccessList(
                          user,
                          pdhSelected,
                          skillsHeatmapSelected,
                          recruitmentSelected,
                          sowBuilderSelected,
                          deliverablesSelected,
                        );

                        if (!pdhSelected &&
                            selectedModuleRole != _notAssignedValue) {
                          if (!skillsHeatmapSelected &&
                              !recruitmentSelected &&
                              !sowBuilderSelected) {
                            selectedModuleRole = _notAssignedValue;
                            user.moduleRole = null;
                          }
                        }
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: pdhSelected
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: pdhSelected
                          ? selectedModuleRole
                          : _notAssignedValue,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C3E50),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      hint: const Text(
                        'Module Role',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: pdhSelected ? Colors.white : Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                      onChanged: pdhSelected
                          ? (value) {
                              SoundSystem.playButtonClick();
                              setState(() {
                                if (value == _notAssignedValue) {
                                  selectedModuleRole = _notAssignedValue;
                                  user.moduleRole = null;
                                } else {
                                  selectedModuleRole = value;
                                  user.moduleRole = value;
                                }
                              });
                            }
                          : null,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: _notAssignedValue,
                          child: Text(_notAssignedValue),
                        ),
                        ..._moduleRoleOptionsPDH.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option,
                            child: Text(option),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'Resource & Capacity Skills Heatmap',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    value: skillsHeatmapSelected,
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      setState(() {
                        skillsHeatmapSelected = value ?? false;
                        _updateModuleAccessList(
                          user,
                          pdhSelected,
                          skillsHeatmapSelected,
                          recruitmentSelected,
                          sowBuilderSelected,
                          deliverablesSelected,
                        );
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: skillsHeatmapSelected
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: skillsHeatmapSelected
                          ? (_selectedSkillsHeatmapRoles[user.id] ??
                                selectedSkillsHeatmapRole)
                          : _notAssignedValue,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C3E50),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      hint: const Text(
                        'Module Role',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: skillsHeatmapSelected
                            ? Colors.white
                            : Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                      onChanged: skillsHeatmapSelected
                          ? (value) {
                              SoundSystem.playButtonClick();
                              setState(() {
                                if (value == _notAssignedValue) {
                                  _selectedSkillsHeatmapRoles[user.id] =
                                      _notAssignedValue;
                                } else {
                                  _selectedSkillsHeatmapRoles[user.id] = value;
                                }
                              });
                            }
                          : null,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: _notAssignedValue,
                          child: Text(_notAssignedValue),
                        ),
                        ..._moduleRoleOptionsSkillsHeatmap.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option,
                            child: Text(option),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'Automated Recruitment Workflow',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    value: recruitmentSelected,
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      SoundSystem.playButtonClick();
                      setState(() {
                        recruitmentSelected = value ?? false;
                        _updateModuleAccessList(
                          user,
                          pdhSelected,
                          skillsHeatmapSelected,
                          recruitmentSelected,
                          sowBuilderSelected,
                          deliverablesSelected,
                        );
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: recruitmentSelected
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: recruitmentSelected
                          ? (_selectedRecruitmentRoles[user.id] ??
                                selectedRecruitmentRole)
                          : _notAssignedValue,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C3E50),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      hint: const Text(
                        'Module Role',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: recruitmentSelected
                            ? Colors.white
                            : Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                      onChanged: recruitmentSelected
                          ? (value) {
                              SoundSystem.playButtonClick();
                              setState(() {
                                if (value == _notAssignedValue) {
                                  _selectedRecruitmentRoles[user.id] =
                                      _notAssignedValue;
                                } else {
                                  _selectedRecruitmentRoles[user.id] = value;
                                }
                              });
                            }
                          : null,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: _notAssignedValue,
                          child: Text(_notAssignedValue),
                        ),
                        ..._moduleRoleOptionsRecruitment.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option,
                            child: Text(option),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'Deliverables & Sprint Sign-Off Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    value: deliverablesSelected,
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      SoundSystem.playButtonClick();
                      setState(() {
                        deliverablesSelected = value ?? false;
                        _updateModuleAccessList(
                          user,
                          pdhSelected,
                          skillsHeatmapSelected,
                          recruitmentSelected,
                          sowBuilderSelected,
                          deliverablesSelected,
                        );
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: deliverablesSelected
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: deliverablesSelected
                          ? (_selectedDeliverablesRoles[user.id] ??
                                selectedDeliverablesRole)
                          : _notAssignedValue,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C3E50),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      hint: const Text(
                        'Module Role',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: deliverablesSelected
                            ? Colors.white
                            : Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                      onChanged: deliverablesSelected
                          ? (value) {
                              SoundSystem.playButtonClick();
                              setState(() {
                                if (value == _notAssignedValue) {
                                  _selectedDeliverablesRoles[user.id] =
                                      _notAssignedValue;
                                } else {
                                  _selectedDeliverablesRoles[user.id] = value;
                                }
                              });
                            }
                          : null,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: _notAssignedValue,
                          child: Text(_notAssignedValue),
                        ),
                        ..._moduleRoleOptionsDeliverables.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option,
                            child: Text(option),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'Proposal & SOW Builder',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    value: sowBuilderSelected,
                    activeColor: const Color(0xFFC10D00),
                    checkColor: Colors.white,
                    onChanged: (bool? value) {
                      SoundSystem.playButtonClick();
                      setState(() {
                        sowBuilderSelected = value ?? false;
                        _updateModuleAccessList(
                          user,
                          pdhSelected,
                          skillsHeatmapSelected,
                          recruitmentSelected,
                          sowBuilderSelected,
                          deliverablesSelected,
                        );
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16.0),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: sowBuilderSelected
                        ? const Color(0xFF2C3E50)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: sowBuilderSelected
                          ? (_selectedSOWBuilderRoles[user.id] ??
                                selectedSOWBuilderRole)
                          : _notAssignedValue,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C3E50),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      hint: const Text(
                        'Module Role',
                        style: TextStyle(
                          color: Colors.white60,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: sowBuilderSelected
                            ? Colors.white
                            : Colors.white54,
                        fontFamily: 'Poppins',
                      ),
                      onChanged: sowBuilderSelected
                          ? (value) {
                              SoundSystem.playButtonClick();
                              setState(() {
                                if (value == _notAssignedValue) {
                                  _selectedSOWBuilderRoles[user.id] =
                                      _notAssignedValue;
                                } else {
                                  _selectedSOWBuilderRoles[user.id] = value;
                                }
                              });
                            }
                          : null,
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: _notAssignedValue,
                          child: Text(_notAssignedValue),
                        ),
                        ..._moduleRoleOptionsSOWBuilder.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option,
                            child: Text(option),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _updatingUserId == user.id
                  ? null
                  : () {
                      SoundSystem.playButtonClick();
                      _updateUserModuleAccess(
                        user,
                        pdhSelected,
                        skillsHeatmapSelected,
                        recruitmentSelected,
                        sowBuilderSelected,
                        deliverablesSelected,
                        selectedModuleRole,
                        _selectedRecruitmentRoles[user.id] ?? _notAssignedValue,
                        _selectedSOWBuilderRoles[user.id] ?? _notAssignedValue,
                        _selectedDeliverablesRoles[user.id] ??
                            _notAssignedValue,
                        _selectedSkillsHeatmapRoles[user.id] ??
                            _notAssignedValue,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: _updatingUserId == user.id
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Update Module Access',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
