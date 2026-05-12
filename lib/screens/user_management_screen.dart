import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/pdh_sync.dart'
    show
        updatePDHUserPartial,
        updateSkillsHeatmapUserPartial,
        updateOnboardingUserPartial,
        syncUserToPDH,
        syncUserToSkillsHeatmap;
import '../models/managed_user.dart';
import '../config/api_config.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sound_system.dart';
import '../services/admin_alert_service.dart';
import '../theme/app_backgrounds.dart';
import '../theme/app_text_colors.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

const String _kAddNewDepartment = '__add_new_department__';
const String _kAddNewDesignation = '__add_new_designation__';
const String _kAllFilterOption = '__all_filter_option__';

class _UserManagementScreenState extends State<UserManagementScreen>
    with WidgetsBindingObserver {
  static const Color _filterPopupDarkBg = Color(0xFF3D3F40);
  static final Color userMgmtDarkWidgetBg = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.10),
    const Color(0xFF3D3F40).withValues(alpha: 0.40),
  );

  String? _updatingUserId;
  Timer? _debounceTimer;
  String _searchQuery = '';

  Future<void> _publishAdminAlert({
    required String title,
    required String message,
    Map<String, dynamic> details = const {},
    bool requiresAck = false,
  }) async {
    final authProvider = context.read<AuthProvider>();
    if ((authProvider.userRole ?? '').toLowerCase() != 'admin') {
      return;
    }
    final actorEmail = (authProvider.userEmail ?? '').trim();
    if (actorEmail.isEmpty) {
      return;
    }
    try {
      await AdminAlertService.publishAdminChange(
        actorEmail: actorEmail,
        title: title,
        message: message,
        area: 'user_management',
        details: details,
        requiresAck: requiresAck,
      );
    } catch (e) {
      debugPrint('[UserManagement] alert publish failed: $e');
    }
  }

  String? expandedUserId;
  String? _hoveredUserId;
  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = <String>{};

  String? _selectedStatus;
  String? _selectedDepartment;
  String? _selectedDesignation;
  final Map<String, String> _editedDepartments = {};
  final Map<String, String> _editedDesignations = {};

  List<String> _departments = [];
  List<String> _designations = [];

  Set<String> get _availableStatuses {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.users.map((user) => user.status).toSet();
  }

  List<String> get _availableDepartments {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final users = userProvider.users;
    final deptOrder = _departments
        .where((d) => d.isNotEmpty)
        .fold<List<String>>(<String>[], (acc, value) {
          if (!acc.contains(value)) acc.add(value);
          return acc;
        });
    if (users.isEmpty) return List<String>.from(deptOrder);
    final fromUsers = users
        .map((user) => user.department)
        .where((d) => d.isNotEmpty)
        .toSet();
    final rest = fromUsers.difference(deptOrder.toSet()).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...deptOrder, ...rest];
  }

  List<String> get _availableDesignations {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final users = userProvider.users;
    final desigOrder = _designations
        .where((d) => d.isNotEmpty)
        .fold<List<String>>(<String>[], (acc, value) {
          if (!acc.contains(value)) acc.add(value);
          return acc;
        });
    if (users.isEmpty) return List<String>.from(desigOrder);
    final fromUsers = users
        .map((user) => user.designation)
        .where((d) => d.isNotEmpty)
        .toSet();
    final rest = fromUsers.difference(desigOrder.toSet()).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [...desigOrder, ...rest];
  }

  String _formatLastSignIn(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return DateFormat('MMM d, yyyy • h:mm a').format(value.toLocal());
  }

  final Map<String, Color> userStatusColors = {
    'Active': Colors.green.shade600,
    'Inactive': Colors.grey.shade600,
    'Pending': Colors.orange.shade500,
  };

  final Map<String, Color> userRoleColors = {
    'Staff': Colors.blue.shade600,
    'Manager': Colors.purple.shade600,
    'Admin': const Color(0xFFC10D00),
  };

  final Map<String, Color> userStatusCircleColors = {
    'Active': Colors.green.shade500,
    'Inactive': Colors.grey.shade500,
    'Pending': Colors.orange.shade500,
  };

  final List<String> userRoles = ['Staff', 'Admin'];

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ManagedUser> get _filteredUsers {
    final userProvider = Provider.of<UserProvider>(context);
    List<ManagedUser> users = userProvider.users;
    final query = _searchQuery.toLowerCase();

    if (query.isNotEmpty) {
      users = users.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.department.toLowerCase().contains(query) ||
            user.designation.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedStatus != null) {
      users = users.where((user) => user.status == _selectedStatus).toList();
    }

    if (_selectedDepartment != null) {
      users = users
          .where((user) => user.department == _selectedDepartment)
          .toList();
    }

    if (_selectedDesignation != null) {
      users = users
          .where((user) => user.designation == _selectedDesignation)
          .toList();
    }

    return users;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    userProvider.fetchUsers(forceRefresh: true);

    if (userProvider.hasCachedData) {
      userProvider.refreshUsersInBackground();
    }
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
    _fetchDepartments();
    _fetchDesignations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ensure the screen reflects the newest backend tracking values
      // (lastSignInAt/loginCount), even if this screen was already open.
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.fetchUsers(forceRefresh: true);
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.departmentsEndpoint));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final raw = data?['departments'];
        final list = raw is List<dynamic>
            ? raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
            : <String>[];
        setState(() => _departments = list);
      }
    } catch (e) {
      debugPrint('Fetch departments failed: $e');
    }
  }

  Future<void> _fetchDesignations() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.designationsEndpoint));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final raw = data?['designations'];
        final list = raw is List<dynamic>
            ? raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
            : <String>[];
        setState(() => _designations = list);
      }
    } catch (e) {
      debugPrint('Fetch designations failed: $e');
    }
  }

  Future<void> _showAddDepartmentDialog({String? initialSelectForUser}) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dialogBg = isDark
        ? const Color(0xFF3D3F40)
        : Colors.white;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          'Add new department',
          style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
          decoration: InputDecoration(
            labelText: 'Department name',
            labelStyle: TextStyle(color: appTextColor(context)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundSystem.playButtonClick();
              Navigator.of(ctx).pop();
            },
            child: Text('Cancel', style: TextStyle(color: appTextColor(context))),
          ),
          ElevatedButton(
            onPressed: () {
              SoundSystem.playButtonClick();
              Navigator.of(ctx).pop(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC10D00)),
            child: Text('Add', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.departmentsEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': result}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final raw = data?['departments'];
        final list = raw is List<dynamic>
            ? raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
            : <String>[];
        if (mounted) {
          setState(() {
            _departments = [result, ...list.where((s) => s != result)];
          });
        }
        if (mounted) {
          SoundSystem.playSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Department "$result" added. You can select it from the list.'), backgroundColor: const Color(0xFFC10D00)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SoundSystem.playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add department: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddDesignationDialog({String? initialSelectForUser}) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dialogBg = isDark
        ? const Color(0xFF3D3F40)
        : Colors.white;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog( 
        backgroundColor: dialogBg,
        title: Text(
          'Add new designation',
          style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
          decoration: InputDecoration(
            labelText: 'Designation name',
            labelStyle: TextStyle(color: appTextColor(context)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SoundSystem.playButtonClick();
              Navigator.of(ctx).pop();
            },
            child: Text('Cancel', style: TextStyle(color: appTextColor(context))),
          ),
          ElevatedButton(
            onPressed: () {
              SoundSystem.playButtonClick();
              Navigator.of(ctx).pop(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC10D00)),
            child: Text('Add', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.designationsEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': result}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final raw = data?['designations'];
        final list = raw is List<dynamic>
            ? raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
            : <String>[];
        if (mounted) {
          setState(() {
            _designations = [result, ...list.where((s) => s != result)];
          });
        }
        if (mounted) {
          SoundSystem.playSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Designation "$result" added. You can select it from the list.'), backgroundColor: const Color(0xFFC10D00)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SoundSystem.playError();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add designation: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            style: TextStyle(fontFamily: 'Poppins'),
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

  Future<void> _updateUserRoleAndStatus(
    String userId,
    String newRole,
    String newStatus, {
    String? oldRole,
    String? oldStatus,
    required String firstName,
    required String lastName,
    required String department,
    required String designation,
    String? entity,
  }) async {
    setState(() {
      _updatingUserId = userId;
    });

    final authProvider = context.read<AuthProvider>();
    final adminEmail = authProvider.userEmail?.trim() ?? '';
    final isSpecialSession = authProvider.isSpecialSession;

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (isSpecialSession) {
        headers['X-Session-Type'] = 'special';
      }

      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(userId)),
        headers: headers,
        body: jsonEncode({
          'role': newRole,
          'status': newStatus,
          'entity': entity,
          'department': department,
          'designation': designation,
          if (adminEmail.isNotEmpty && !isSpecialSession)
            'adminApproved': adminEmail,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update user $userId: ${response.statusCode} ${response.body}',
        );
      }

      if (mounted) {
        SoundSystem.playSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User updated for $firstName $lastName.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: appTextColor(context),
              ),
            ),
            backgroundColor: const Color(0xFFC10D00),
          ),
        );
      }
      await _publishAdminAlert(
        title: 'Role/permission change feed',
        message:
            '$firstName $lastName role changed from "${oldRole ?? newRole}" to "$newRole"; status from "${oldStatus ?? newStatus}" to "$newStatus".',
        details: {
          'userId': userId,
          'userName': '$firstName $lastName',
          'oldRole': oldRole ?? newRole,
          'role': newRole,
          'oldStatus': oldStatus ?? newStatus,
          'status': newStatus,
          'approvedBy': adminEmail,
          'effectiveDateIso': DateTime.now().toUtc().toIso8601String(),
          'department': department,
          'designation': designation,
          'entity': entity ?? '',
        },
      );

      final adminField = adminEmail.isNotEmpty
          ? {
              'admin': {'approved': adminEmail},
            }
          : null;

      try {
        await updatePDHUserPartial(
          userId,
          {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
          onboardingFields: {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('PDH sync failed for user update: $e');
        if (mounted) {
          SoundSystem.playError();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User info updated, but failed to sync with PDH.',
                style: TextStyle(fontFamily: 'Poppins', color: appTextColor(context)),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      try {
        await updateSkillsHeatmapUserPartial(
          userId,
          {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
          onboardingFields: {
            'role': newRole,
            'status': newStatus,
            'entity': entity,
            'department': department,
            'designation': designation,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('Skills Heatmap sync failed for user update: $e');
      }

      try {
        await updateOnboardingUserPartial(userId, {
          'role': newRole,
          'status': newStatus,
          'entity': entity,
          'department': department,
          'designation': designation,
          if (adminField != null) ...adminField,
        });
      } catch (e) {
        debugPrint('Onboarding sync failed for user update: $e');
      }

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
          final backendUser = decoded?['user'] as Map<String, dynamic>?;
          if (backendUser != null) {
            final existingIndex = userProvider.users.indexWhere(
              (u) => u.id == userId,
            );
            final existing = existingIndex >= 0
                ? userProvider.users[existingIndex]
                : null;
            final updatedUser = _mergeBackendUserData(
              existing,
              backendUser,
              fallbackDepartment: department,
              fallbackDesignation: designation,
              fallbackRole: newRole,
              fallbackStatus: newStatus,
              fallbackEntity: entity,
            );
            userProvider.updateUser(updatedUser);
            _editedDepartments.remove(userId);
            _editedDesignations.remove(userId);
          } else {
            final users = userProvider.users;
            final index = users.indexWhere((u) => u.id == userId);
            if (index != -1) {
              users[index].role = newRole;
              users[index].status = newStatus;
              if (entity != null) {
                users[index].entity = entity;
              }
              userProvider.updateUser(
                users[index].copyWith(
                  department: department,
                  designation: designation,
                ),
              );
            }
          }
        } catch (_) {
          final users = userProvider.users;
          final index = users.indexWhere((u) => u.id == userId);
          if (index != -1) {
            users[index].role = newRole;
            users[index].status = newStatus;
            if (entity != null) {
              users[index].entity = entity;
            }
            userProvider.updateUser(
              users[index].copyWith(
                department: department,
                designation: designation,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserId = null;
          // Ensure expandedUserId is preserved during the state update
          // Note: We don't modify expandedUserId here, so it remains unchanged
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color widgetBg = isDark
        ? userMgmtDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);

    return Scaffold(
      bottomNavigationBar: _isSelectionMode && _selectedUserIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: widgetBg,
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
                      style: TextStyle(
                        color: appTextColor(context),
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
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: appTextColor(context),
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
                          child: Text(
                            'Select all',
                            style: TextStyle(
                              color: appTextColor(context),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () {
                            SoundSystem.playButtonClick();
                            _showBulkUpdateDialog(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC10D00),
                            foregroundColor: appTextColor(context),
                          ),
                          child: Text(
                            'Update',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () {
                            SoundSystem.playButtonClick();
                            _showDeleteConfirmation(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: appTextColor(context),
                          ),
                          child: Text(
                            'Delete',
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
            child: Image.asset(
              appBackgroundAsset(context),
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll<Color>(appTextColor(context)),
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
                        _buildFiltersAndSearch(),
                        const SizedBox(height: 16.0),
                        _buildUserList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isSelectionMode)
                    FloatingActionButton(
                      heroTag: 'user_management_add_fab',
                      onPressed: () {
                        SoundSystem.playButtonClick();
                        _showAddUserDialog(context);
                      },
                      backgroundColor: const Color(0xFFC10D00),
                      shape: const CircleBorder(),
                      child: Icon(Icons.add, color: appTextColor(context)),
                    ),
                ],
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
                'User Management',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: appTextColor(context),
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
                  : Icon(Icons.refresh, color: appTextColor(context)),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          'Empowering Your Workforce Through Management.',
          style: TextStyle(
            color: appTextColor(context),
            fontSize: 14.0,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersAndSearch() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color widgetBg = isDark
        ? userMgmtDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);
    final Color popupBg = isDark ? _filterPopupDarkBg : Colors.white;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: widgetBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: appTextColor(context).withValues(alpha: 0.25),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    hint: Text(
                      'FILTER STATUS',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                      ),
                    ),
                    dropdownColor: popupBg,
                    style: TextStyle(
                      color: appTextColor(context),
                      fontFamily: 'Poppins',
                    ),
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: appTextColor(context),
                    ),
                    onChanged: (String? newValue) {
                      SoundSystem.playButtonClick();
                      setState(() {
                        _selectedStatus = newValue;
                      });
                    },
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All Statuses',
                          style: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ..._availableStatuses.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: appTextColor(context),
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildSearchableFilterField(
                placeholder: 'FILTER DEPARTMENT',
                valueText: _selectedDepartment ?? 'All Departments',
                widgetBg: widgetBg,
                onTap: () async {
                  SoundSystem.playButtonClick();
                  final selected = await _showSearchableFilterDialog(
                    title: 'Department',
                    allLabel: 'All Departments',
                    options: _availableDepartments,
                    addValue: _kAddNewDepartment,
                    addLabel: 'Add new department...',
                  );
                  if (selected == null) return;
                  if (selected == _kAddNewDepartment) {
                    await _showAddDepartmentDialog();
                    return;
                  }
                  setState(() {
                    _selectedDepartment =
                        selected == _kAllFilterOption ? null : selected;
                  });
                },
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildSearchableFilterField(
                placeholder: 'FILTER DESIGNATION',
                valueText: _selectedDesignation ?? 'All Designations',
                widgetBg: widgetBg,
                onTap: () async {
                  SoundSystem.playButtonClick();
                  final selected = await _showSearchableFilterDialog(
                    title: 'Designation',
                    allLabel: 'All Designations',
                    options: _availableDesignations,
                    addValue: _kAddNewDesignation,
                    addLabel: 'Add new designation...',
                  );
                  if (selected == null) return;
                  if (selected == _kAddNewDesignation) {
                    await _showAddDesignationDialog();
                    return;
                  }
                  setState(() {
                    _selectedDesignation =
                        selected == _kAllFilterOption ? null : selected;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(
              color: appTextColor(context),
              fontFamily: 'Poppins',
            ),
            prefixIcon: Icon(Icons.search, color: appTextColor(context)),
            suffixIcon: IconButton(
              icon: Icon(Icons.close, color: appTextColor(context)),
              onPressed: () {
                SoundSystem.playButtonClick();
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            ),
            filled: true,
            fillColor: widgetBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
          ),
          style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
        ),
      ],
    );
  }

  Widget _buildSearchableFilterField({
    required String placeholder,
    required String valueText,
    required Color widgetBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: widgetBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: appTextColor(context).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText.isEmpty ? placeholder : valueText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: appTextColor(context)),
          ],
        ),
      ),
    );
  }

  Future<String?> _showSearchableFilterDialog({
    required String title,
    required String allLabel,
    required List<String> options,
    String? addValue,
    String? addLabel,
  }) async {
    final searchController = TextEditingController();
    String query = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final dialogBg = isDark ? _filterPopupDarkBg : Colors.white;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = options
                .where(
                  (option) =>
                      option.toLowerCase().contains(query.trim().toLowerCase()),
                )
                .toList();
            final rows = <Map<String, String>>[
              {'value': _kAllFilterOption, 'label': allLabel},
              if (addValue != null && addLabel != null)
                {'value': addValue, 'label': '➕ $addLabel'},
              ...filtered.map((value) => {'value': value, 'label': value}),
            ];
            final visibleItems = rows.length < 10 ? rows.length : 10;
            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                title,
                style: TextStyle(
                  color: appTextColor(dialogContext),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setDialogState(() {
                          query = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search $title',
                        hintStyle: TextStyle(
                          color: appTextColor(dialogContext).withValues(alpha: 0.7),
                          fontFamily: 'Poppins',
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: appTextColor(dialogContext),
                        ),
                        filled: true,
                        fillColor: dialogBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(
                        color: appTextColor(dialogContext),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No results found',
                          style: TextStyle(
                            color: appTextColor(dialogContext),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (visibleItems * 48).toDouble(),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                row['label'] ?? '',
                                style: TextStyle(
                                  color: appTextColor(dialogContext),
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onTap: () => Navigator.of(dialogContext).pop(
                                row['value'],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    return selected;
  }

  Widget _buildUserList() {
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.isLoading && userProvider.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFC10D00)),
            const SizedBox(height: 24.0),
            Text(
              'Please wait. We\'re loading all users...',
              style: TextStyle(
                color: appTextColor(context),
                fontSize: 16.0,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      );
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
                style: TextStyle(
                  color: appTextColor(context),
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
                icon: Icon(Icons.refresh),
                label: Text('Retry', style: TextStyle(fontFamily: 'Poppins')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (userProvider.users.isEmpty && !userProvider.isLoading) {
      return Center(
        child: Text(
          'No onboarding users found.',
          style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
        ),
      );
    }

    return Column(
      children: _filteredUsers.map((user) {
        final bool isExpanded = expandedUserId == user.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            children: [
              _buildUserRow(user, isExpanded),
              if (isExpanded) _buildDropdownContent(user),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserAvatar(ManagedUser user) {
    final url = user.profilePictureUrl;
    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: appTextColor(context).withValues(alpha: 0.24),
        backgroundImage: NetworkImage(url.trim()),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: appTextColor(context).withValues(alpha: 0.24),
      child: Icon(Icons.person, size: 24, color: appTextColor(context)),
    );
  }

  Widget _buildUserRow(ManagedUser user, bool isExpanded) {
    final isSelected = _selectedUserIds.contains(user.id);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color normalWidgetBg = isDark
        ? userMgmtDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);
    final bool isHovered = _hoveredUserId == user.id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredUserId = user.id),
      onExit: (_) {
        if (_hoveredUserId == user.id) {
          setState(() => _hoveredUserId = null);
        }
      },
      child: AnimatedScale(
        scale: isHovered ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        child: GestureDetector(
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
                expandedUserId = isExpanded ? null : user.id;
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0x80C10D00) : normalWidgetBg,
              borderRadius: BorderRadius.circular(16.0),
              border: isSelected
                  ? Border.all(color: const Color(0xFFC10D00), width: 2.0)
                  : Border.all(
                      color: isHovered
                          ? const Color(0xFFC10D00).withValues(alpha: 0.70)
                          : appTextColor(context).withValues(alpha: 0.12),
                      width: isHovered ? 1.6 : 1.0,
                    ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFFC10D00).withValues(
                          alpha: isDark ? 0.28 : 0.18,
                        ),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final checkboxWidth = _isSelectionMode ? 48.0 : 0.0;
            final spacingWidth = 8.0 * 2;
            final columnWidth =
                ((availableWidth - checkboxWidth) - spacingWidth) / 3;
            final leftPadding = columnWidth * 0.12;

            final secondColumnWidth = columnWidth - leftPadding;

            return Row(
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
                    checkColor: appTextColor(context),
                  ),
                  const SizedBox(width: 8.0),
                ],

                SizedBox(
                  width: columnWidth,
                  child: Row(
                    children: [
                      _buildUserAvatar(user),
                      const SizedBox(width: 12.0),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                color: appTextColor(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0,
                                fontFamily: 'Poppins',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                color: appTextColor(context),
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
                const SizedBox(width: 8.0),

                Padding(
                  padding: EdgeInsets.only(left: leftPadding),
                  child: SizedBox(
                    width: secondColumnWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.designation,
                          style: TextStyle(
                            color: appTextColor(context),
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
                          style: TextStyle(
                            color: appTextColor(context),
                            fontSize: 12.0,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),

                SizedBox(
                  width: columnWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (user.role.toLowerCase() != 'user') ...[
                        Flexible(child: _buildRoleBadge(user.role)),
                        const SizedBox(width: 8.0),
                      ],
                      Flexible(child: _buildStatusBadge(user.status)),
                      if (!_isSelectionMode) ...[
                        const SizedBox(width: 8.0),
                        Transform.rotate(
                          angle: isExpanded ? 3.14 : 0,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: appTextColor(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: userRoleColors[role],
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: userStatusColors[status],
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdownContent(ManagedUser user) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelBg = isDark
        ? userMgmtDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);
    final Color popupBg = isDark ? _filterPopupDarkBg : Colors.white;
    final Color dividerColor = appTextColor(context).withValues(
      alpha: isDark ? 0.22 : 0.30,
    );

    String selectedRole = user.role;
    String selectedStatusLocal = user.status;
    String selectedDepartmentLocal =
        _editedDepartments[user.id] ?? user.department;
    String selectedDesignationLocal =
        _editedDesignations[user.id] ?? user.designation;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Role: ',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value: userRoles.contains(selectedRole)
                            ? selectedRole
                            : null,
                        hint: Text(
                          'Select role',
                          style: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: popupBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: appTextColor(context),
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) {
                          SoundSystem.playButtonClick();
                          if (newValue != null && newValue != selectedRole) {
                            // Store current expanded state before setState
                            final currentExpandedUserId = expandedUserId;

                            setState(() {
                              selectedRole = newValue;
                              user.role = newValue;
                              // Preserve the expanded state
                              expandedUserId = currentExpandedUserId;
                            });
                            // Auto-save the role change
                            _updateUserRoleAndStatus(
                              user.id,
                              newValue,
                              user.status,
                              oldRole: selectedRole,
                              oldStatus: user.status,
                              firstName: user.firstName,
                              lastName: user.lastName,
                              department: user.department,
                              designation: user.designation,
                              entity: user.entity,
                            );
                          }
                        },
                        items: userRoles.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                color: appTextColor(context),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Status: ',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value:
                            ['Active', 'Pending'].contains(selectedStatusLocal)
                            ? selectedStatusLocal
                            : null,
                        hint: Text(
                          'Select status',
                          style: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: popupBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: appTextColor(context),
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) {
                          SoundSystem.playButtonClick();
                          if (newValue != null &&
                              newValue != selectedStatusLocal) {
                            // Store current expanded state before setState
                            final currentExpandedUserId = expandedUserId;

                            setState(() {
                              selectedStatusLocal = newValue;
                              user.status = newValue;
                              // Preserve the expanded state
                              expandedUserId = currentExpandedUserId;
                            });
                            // Auto-save the status change
                            _updateUserRoleAndStatus(
                              user.id,
                              user.role,
                              newValue,
                              oldRole: user.role,
                              oldStatus: selectedStatusLocal,
                              firstName: user.firstName,
                              lastName: user.lastName,
                              department: user.department,
                              designation: user.designation,
                              entity: user.entity,
                            );
                          }
                        },
                        items: ['Active', 'Pending']
                            .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    color: appTextColor(context),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Department: ',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value: selectedDepartmentLocal.isNotEmpty &&
                                _availableDepartments.contains(
                                  selectedDepartmentLocal,
                                )
                            ? selectedDepartmentLocal
                            : null,
                        hint: Text(
                          'Select department',
                          style: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: popupBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: appTextColor(context),
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) async {
                          SoundSystem.playButtonClick();
                          if (newValue == _kAddNewDepartment) {
                            await _showAddDepartmentDialog(initialSelectForUser: user.id);
                            if (mounted) setState(() {});
                            return;
                          }
                          setState(() {
                            selectedDepartmentLocal = newValue ?? '';
                            if (selectedDepartmentLocal.isNotEmpty) {
                              _editedDepartments[user.id] =
                                  selectedDepartmentLocal;
                            } else {
                              _editedDepartments.remove(user.id);
                            }
                          });
                        },
                        items: [
                          const DropdownMenuItem<String>(
                            value: _kAddNewDepartment,
                            child: Text('➕ Add new department...'),
                          ),
                          ..._availableDepartments.map<DropdownMenuItem<String>>(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Designation: ',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      height: 40.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: DropdownButton<String>(
                        value: selectedDesignationLocal.isNotEmpty &&
                                _availableDesignations.contains(
                                  selectedDesignationLocal,
                                )
                            ? selectedDesignationLocal
                            : null,
                        hint: Text(
                          'Select designation',
                          style: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        dropdownColor: popupBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                          fontSize: 14.0,
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: appTextColor(context),
                        ),
                        underline: const SizedBox.shrink(),
                        onChanged: (String? newValue) async {
                          SoundSystem.playButtonClick();
                          if (newValue == _kAddNewDesignation) {
                            await _showAddDesignationDialog(initialSelectForUser: user.id);
                            if (mounted) setState(() {});
                            return;
                          }
                          setState(() {
                            selectedDesignationLocal = newValue ?? '';
                            if (selectedDesignationLocal.isNotEmpty) {
                              _editedDesignations[user.id] =
                                  selectedDesignationLocal;
                            } else {
                              _editedDesignations.remove(user.id);
                            }
                          });
                        },
                        items: [
                          const DropdownMenuItem<String>(
                            value: _kAddNewDesignation,
                            child: Text('➕ Add new designation...'),
                          ),
                          ..._availableDesignations.map<DropdownMenuItem<String>>(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Managed by: ',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    GestureDetector(
                      onTap: () {
                        SoundSystem.playButtonClick();
                        _showManagedByDialog(user);
                      },
                      child: Container(
                        height: 40.0,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: panelBg,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                user.manager?.isNotEmpty == true
                                    ? user.manager!
                                    : 'Select manager',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: appTextColor(context),
                                  fontFamily: 'Poppins',
                                  fontSize: 14.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Icon(
                              Icons.arrow_drop_down,
                              color: appTextColor(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Divider(color: dividerColor, thickness: 1),
          const SizedBox(height: 8.0),
          Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                  fontSize: 14.0,
                ),
                children: [
                  TextSpan(
                    text: 'Last sign in: ',
                    style: TextStyle(color: appTextColor(context)),
                  ),
                  TextSpan(text: _formatLastSignIn(user.lastSignInAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                  fontSize: 14.0,
                ),
                children: [
                  TextSpan(
                    text: 'Login count: ',
                    style: TextStyle(color: appTextColor(context)),
                  ),
                  TextSpan(text: '${user.loginCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Divider(color: dividerColor, thickness: 1),
          const SizedBox(height: 8.0),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _updatingUserId == user.id
                  ? null
                  : () {
                      SoundSystem.playButtonClick();
                      _updateUserRoleAndStatus(
                        user.id,
                        user.role,
                        user.status,
                        oldRole: user.role,
                        oldStatus: user.status,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        department: selectedDepartmentLocal,
                        designation: selectedDesignationLocal,
                        entity: user.entity,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
                foregroundColor: appTextColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(45.0),
                ),
              ),
              child: _updatingUserId == user.id
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(appTextColor(context)),
                      ),
                    )
                  : Text(
                      'Update',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserManager(ManagedUser user, ManagedUser manager) async {
    final authProvider = context.read<AuthProvider>();
    final adminEmail = authProvider.userEmail?.trim() ?? '';
    final isSpecialSession = authProvider.isSpecialSession;

    final managerFullName =
        '${manager.firstName} ${manager.lastName}'.trim().isNotEmpty
        ? '${manager.firstName} ${manager.lastName}'.trim()
        : manager.name;

    setState(() {
      _updatingUserId = user.id;
      user.manager = managerFullName;
      // Preserve expandedUserId - we don't modify it here
    });

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (isSpecialSession) {
        headers['X-Session-Type'] = 'special';
      }

      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(user.id)),
        headers: headers,
        body: jsonEncode({
          'manager': managerFullName,
          if (adminEmail.isNotEmpty && !isSpecialSession)
            'adminApproved': adminEmail,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update manager for ${user.id}: ${response.statusCode} ${response.body}',
        );
      }

      if (!mounted) return;

      try {
        await updatePDHUserPartial(
          user.id,
          {'manager': managerFullName},
          onboardingFields: {'manager': managerFullName},
        );
      } catch (e) {
        debugPrint('PDH manager sync failed: $e');
      }

      try {
        await updateSkillsHeatmapUserPartial(
          user.id,
          {'manager': managerFullName},
          onboardingFields: {'manager': managerFullName},
        );
      } catch (e) {
        debugPrint('Skills Heatmap manager sync failed: $e');
      }

      try {
        await updateOnboardingUserPartial(user.id, {
          'manager': managerFullName,
        });
      } catch (e) {
        debugPrint('Onboarding manager sync failed: $e');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
      final backendUser = decoded?['user'] as Map<String, dynamic>?;
      if (backendUser != null && mounted) {
        final updatedUser = _mergeBackendUserData(
          user,
          backendUser,
          fallbackDepartment: user.department,
          fallbackDesignation: user.designation,
          fallbackRole: user.role,
          fallbackStatus: user.status,
          fallbackEntity: user.entity,
        );
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.updateUser(updatedUser);
      }

      if (mounted) {
        SoundSystem.playSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manager set to $managerFullName for ${user.name}.'),
          ),
        );
      }
      await _publishAdminAlert(
        title: 'Manager assignment updated',
        message: 'Manager for ${user.name} changed to $managerFullName.',
        details: {
          'userId': user.id,
          'userName': user.name,
          'manager': managerFullName,
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingUserId = null;
          // Ensure expandedUserId is preserved during the state update
          // Note: We don't modify expandedUserId here, so it remains unchanged
        });
      }
    }
  }

  ManagedUser _mergeBackendUserData(
    ManagedUser? existingUser,
    Map<String, dynamic> backendUser, {
    required String fallbackDepartment,
    required String fallbackDesignation,
    required String fallbackRole,
    required String fallbackStatus,
    String? fallbackEntity,
  }) {
    final parsed = ManagedUser.fromApi(backendUser);
    return parsed.copyWith(
      firstName: parsed.firstName.isNotEmpty
          ? parsed.firstName
          : existingUser?.firstName,
      lastName: parsed.lastName.isNotEmpty
          ? parsed.lastName
          : existingUser?.lastName,
      email: parsed.email.isNotEmpty ? parsed.email : existingUser?.email,
      department: parsed.department.isNotEmpty
          ? parsed.department
          : (existingUser?.department.isNotEmpty == true
                ? existingUser!.department
                : fallbackDepartment),
      designation: parsed.designation.isNotEmpty
          ? parsed.designation
          : (existingUser?.designation.isNotEmpty == true
                ? existingUser!.designation
                : fallbackDesignation),
      role: parsed.role.isNotEmpty ? parsed.role : fallbackRole,
      status: parsed.status.isNotEmpty ? parsed.status : fallbackStatus,
      entity: (parsed.entity ?? '').trim().isNotEmpty
          ? parsed.entity
          : (existingUser?.entity ?? fallbackEntity),
      manager: (parsed.manager ?? '').trim().isNotEmpty
          ? parsed.manager
          : existingUser?.manager,
      moduleAccess: (parsed.moduleAccess ?? '').trim().isNotEmpty
          ? parsed.moduleAccess
          : existingUser?.moduleAccess,
      moduleRole: (parsed.moduleRole ?? '').trim().isNotEmpty
          ? parsed.moduleRole
          : existingUser?.moduleRole,
      moduleAccessRole: (parsed.moduleAccessRole ?? '').trim().isNotEmpty
          ? parsed.moduleAccessRole
          : existingUser?.moduleAccessRole,
      phoneNumber: (parsed.phoneNumber ?? '').trim().isNotEmpty
          ? parsed.phoneNumber
          : existingUser?.phoneNumber,
      profilePictureUrl: (parsed.profilePictureUrl ?? '').trim().isNotEmpty
          ? parsed.profilePictureUrl
          : existingUser?.profilePictureUrl,
      createdAt: parsed.createdAt ?? existingUser?.createdAt,
      updatedAt: parsed.updatedAt ?? DateTime.now(),
      lastSignInAt: parsed.lastSignInAt ?? existingUser?.lastSignInAt,
      loginCount: parsed.loginCount > 0
          ? parsed.loginCount
          : (existingUser?.loginCount ?? 0),
    );
  }

  void _showManagedByDialog(ManagedUser user) {
    final userProvider = context.read<UserProvider>();
    final allUsers = userProvider.users;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dialogBg = isDark
        ? const Color(0xFF3D3F40)
        : Colors.white;

    final TextEditingController searchController = TextEditingController();
    ManagedUser? selectedManager;
    String query = '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final lowerQuery = query.toLowerCase().trim();
            final filtered = allUsers.where((candidate) {
              if (candidate.id == user.id) {
                return false;
              }

              if (candidate.department == 'Operations' &&
                  candidate.designation == 'Learner') {
                return false;
              }

              if (lowerQuery.isEmpty) {
                return true;
              }

              final name = candidate.name.toLowerCase();
              final email = candidate.email.toLowerCase();
              return name.contains(lowerQuery) || email.contains(lowerQuery);
            }).toList();

            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                'Managed by: ${user.name}',
                style: TextStyle(
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                ),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                        ),
                        decoration: InputDecoration(
                          labelText: 'Search manager',
                          labelStyle: TextStyle(
                            color: appTextColor(context),
                            fontFamily: 'Poppins',
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: appTextColor(context).withValues(alpha: 0.24)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFFC10D00)),
                          ),
                        ),
                        onChanged: (value) {
                          setStateDialog(() {
                            query = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12.0),
                      SizedBox(
                        height: 260,
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No users match your search.',
                                  style: TextStyle(
                                    color: appTextColor(context),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final candidate = filtered[index];
                                  final isSelected =
                                      selectedManager?.id == candidate.id;
                                  return ListTile(
                                    title: Text(
                                      candidate.name,
                                      style: TextStyle(
                                        color: appTextColor(context),
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    subtitle: Text(
                                      candidate.email,
                                      style: TextStyle(
                                        color: appTextColor(context),
                                        fontFamily: 'Poppins',
                                        fontSize: 12.0,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? Icon(
                                            Icons.check,
                                            color: Color(0xFFC10D00),
                                          )
                                        : null,
                                    onTap: () {
                                      SoundSystem.playButtonClick();
                                      setStateDialog(() {
                                        selectedManager = candidate;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    SoundSystem.playButtonClick();
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: appTextColor(context),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedManager == null
                      ? null
                      : () async {
                          SoundSystem.playButtonClick();
                          final manager = selectedManager!;
                          Navigator.of(dialogContext).pop();
                          await _updateUserManager(user, manager);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: appTextColor(context),
                  ),
                  child: Text(
                    'Save',
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

  void _showAddUserDialog(BuildContext context) {
    final TextEditingController emailsController = TextEditingController();
    bool isCreating = false;
    String? progressMessage;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color dialogBg = isDark
                ? const Color(0xFF3D3F40)
                : Colors.white;
            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                'Add New Users',
                style: TextStyle(
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paste emails (one per line or with "email:" prefix)',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Example:\nemail: nathi.radebez@khonology.com\nemail: john.doe@khonology.com',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: emailsController,
                      maxLines: 10,
                      minLines: 5,
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                      ),
                      decoration: InputDecoration(
                        labelText: 'Emails',
                        labelStyle: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                        ),
                        hintText:
                            'email: user.name@khonology.com\nemail: another.user@khonology.com',
                        hintStyle: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: appTextColor(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(
                            color: Color(0xFFC10D00),
                          ),
                        ),
                      ),
                    ),
                    if (progressMessage != null) ...[
                      const SizedBox(height: 16.0),
                      Text(
                        progressMessage!,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () {
                          SoundSystem.playButtonClick();
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: appTextColor(context),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          SoundSystem.playButtonClick();
                          final emailsText = emailsController.text.trim();

                          if (emailsText.isEmpty) {
                            SoundSystem.playError();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please paste at least one email',
                                  style: TextStyle(fontFamily: 'Poppins'),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final emails = _parseEmails(emailsText);

                          if (emails.isEmpty) {
                            SoundSystem.playError();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No valid emails found. Please check the format.',
                                  style: TextStyle(fontFamily: 'Poppins'),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isCreating = true;
                            progressMessage =
                                'Creating ${emails.length} user(s)...';
                          });

                          try {
                            final result = await _createMultipleUsers(emails, (
                              message,
                            ) {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  progressMessage = message;
                                });
                              }
                            });

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                              _showCreationSummary(context, result);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error creating users: ${e.toString()}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isCreating = false;
                                progressMessage = null;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: appTextColor(context),
                  ),
                  child: isCreating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              appTextColor(context),
                            ),
                          ),
                        )
                      : Text(
                          'Create Users',
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

  List<String> _parseEmails(String text) {
    final List<String> emails = [];
    final lines = text.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.toLowerCase().startsWith('email:')) {
        final email = line.substring(6).trim();
        if (email.isNotEmpty && email.contains('@')) {
          emails.add(email);
        }
      } else if (line.contains('@')) {
        emails.add(line);
      }
    }

    return emails;
  }

  String _extractNameFromEmail(String email) {
    final emailParts = email.split('@');
    if (emailParts.isEmpty) return email;

    final localPart = emailParts[0];

    final nameParts = localPart.split('.');
    final capitalizedParts = nameParts.map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).toList();

    return capitalizedParts.join(' ');
  }

  bool _userExists(String email) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    return userProvider.users.any(
      (user) => user.email.toLowerCase() == email.toLowerCase(),
    );
  }

  Future<Map<String, dynamic>> _createMultipleUsers(
    List<String> emails,
    Function(String) onProgress,
  ) async {
    int successCount = 0;
    int failureCount = 0;
    int skippedCount = 0;
    final List<String> successEmails = [];
    final List<String> failureEmails = [];
    final List<String> skippedEmails = [];
    final List<String> errorMessages = [];

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.users.isEmpty) {
      onProgress('Loading existing users...');
      await userProvider.fetchUsers(forceRefresh: true);
    }

    final validEmails = <String>[];
    for (final email in emails) {
      final trimmedEmail = email.trim();
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        failureCount++;
        failureEmails.add(trimmedEmail.isEmpty ? email : trimmedEmail);
        errorMessages.add('Invalid email format');
      } else if (_userExists(trimmedEmail)) {
        skippedCount++;
        skippedEmails.add(trimmedEmail);
      } else {
        validEmails.add(trimmedEmail);
      }
    }

    if (validEmails.isEmpty) {
      return {
        'successCount': 0,
        'failureCount': failureCount,
        'skippedCount': skippedCount,
        'successEmails': [],
        'failureEmails': failureEmails,
        'skippedEmails': skippedEmails,
        'errorMessages': errorMessages,
      };
    }

    const int batchSize = 10;
    int processedCount = 0;
    final totalEmails = validEmails.length;

    for (int i = 0; i < validEmails.length; i += batchSize) {
      final batch = validEmails.skip(i).take(batchSize).toList();
      final batchNumber = (i ~/ batchSize) + 1;
      final totalBatches = (validEmails.length / batchSize).ceil();

      onProgress(
        'Processing batch $batchNumber of $totalBatches (${processedCount + batch.length}/$totalEmails users)...',
      );

      final results = await Future.wait(
        batch.map((email) async {
          try {
            final fullName = _extractNameFromEmail(email);
            await _createNewUser(fullName, email, skipRefresh: true);
            return {'success': true, 'email': email, 'error': null};
          } catch (e) {
            debugPrint('Failed to create user $email: $e');
            return {'success': false, 'email': email, 'error': e.toString()};
          }
        }),
        eagerError: false,
      );

      for (final result in results) {
        if (result['success'] as bool) {
          successCount++;
          successEmails.add(result['email'] as String);
        } else {
          failureCount++;
          failureEmails.add(result['email'] as String);
          errorMessages.add(result['error'] as String? ?? 'Unknown error');
        }
        processedCount++;
      }

      onProgress(
        'Progress: $processedCount/$totalEmails users processed ($successCount created, $failureCount failed, $skippedCount skipped)',
      );

      if (i + batchSize < validEmails.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

      if (successCount > 0) {
      onProgress('Refreshing user list...');

      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchUsers(forceRefresh: true);
      }

      await _publishAdminAlert(
        title: 'New users added',
        message: '$successCount user(s) were added from User Management.',
        details: {
          'successCount': successCount,
          'failureCount': failureCount,
          'skippedCount': skippedCount,
          'successEmails': successEmails,
        },
      );
    }

    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'skippedCount': skippedCount,
      'successEmails': successEmails,
      'failureEmails': failureEmails,
      'skippedEmails': skippedEmails,
      'errorMessages': errorMessages,
    };
  }

  void _showCreationSummary(BuildContext context, Map<String, dynamic> result) {
    final successCount = result['successCount'] as int;
    final failureCount = result['failureCount'] as int;
    final skippedCount = result['skippedCount'] as int;
    final successEmails = result['successEmails'] as List<String>;
    final failureEmails = result['failureEmails'] as List<String>;
    final skippedEmails = result['skippedEmails'] as List<String>;
    final errorMessages = result['errorMessages'] as List<String>;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color dialogBg = isDark
            ? const Color(0xFF3D3F40)
            : Colors.white;
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(
            'Creation Summary',
            style: TextStyle(
              color: appTextColor(context),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully created: $successCount user(s)',
                  style: TextStyle(
                    color: Colors.green,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (skippedCount > 0) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    'Skipped (already exists): $skippedCount user(s)',
                    style: TextStyle(
                      color: Colors.orange,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (failureCount > 0) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    'Failed: $failureCount user(s)',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (successEmails.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    'Successfully created:',
                    style: TextStyle(
                      color: appTextColor(context),
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  ...successEmails
                      .take(10)
                      .map(
                        (email) => Padding(
                          padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                          child: Text(
                            '• $email',
                            style: TextStyle(
                              color: Colors.green,
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                            ),
                          ),
                        ),
                      ),
                  if (successEmails.length > 10)
                    Text(
                      '... and ${successEmails.length - 10} more',
                      style: TextStyle(
                        color: Colors.green,
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
                if (failureEmails.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    'Failed:',
                    style: TextStyle(
                      color: appTextColor(context),
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  ...failureEmails.asMap().entries.take(10).map((entry) {
                    final index = entry.key;
                    final email = entry.value;
                    final errorMsg = index < errorMessages.length
                        ? errorMessages[index]
                        : 'Unknown error';
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• $email',
                            style: TextStyle(
                              color: Colors.red,
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                            ),
                          ),
                          if (errorMsg.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                                top: 2.0,
                              ),
                              child: Text(
                                errorMsg.length > 50
                                    ? '${errorMsg.substring(0, 50)}...'
                                    : errorMsg,
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontFamily: 'Poppins',
                                  fontSize: 10.0,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (failureEmails.length > 10)
                    Text(
                      '... and ${failureEmails.length - 10} more',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
                if (skippedEmails.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    'Skipped (already exists):',
                    style: TextStyle(
                      color: appTextColor(context),
                      fontFamily: 'Poppins',
                      fontSize: 12.0,
                    ),
                  ),
                  ...skippedEmails.take(10).map((email) {
                    final name = _extractNameFromEmail(email);
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• $email',
                            style: TextStyle(
                              color: Colors.orange,
                              fontFamily: 'Poppins',
                              fontSize: 11.0,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                            child: Text(
                              '($name)',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontFamily: 'Poppins',
                                fontSize: 10.0,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (skippedEmails.length > 10)
                    Text(
                      '... and ${skippedEmails.length - 10} more',
                      style: TextStyle(
                        color: Colors.orange,
                        fontFamily: 'Poppins',
                        fontSize: 11.0,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                SoundSystem.playButtonClick();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
                foregroundColor: appTextColor(context),
              ),
              child: Text('OK', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewUser(
    String fullName,
    String email, {
    bool skipRefresh = false,
  }) async {
    final nameParts = fullName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final adminEmail = context.read<AuthProvider>().userEmail?.trim() ?? '';

    try {
      final registerResponse = await http.post(
        Uri.parse(ApiConfig.authRegisterEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': 'password',
          'name': fullName,
          'firstName': firstName,
          'lastName': lastName,
          'role': 'Staff',
          'department': '',
          'designation': '',
        }),
      );

      if (registerResponse.statusCode != 201) {
        final errorBody = registerResponse.body;
        throw Exception(
          'Failed to create user: ${registerResponse.statusCode} - $errorBody',
        );
      }

      final responseData = json.decode(registerResponse.body);
      final userPayload = responseData['user'] as Map<String, dynamic>? ?? {};
      final String uid = userPayload['id'] ?? '';

      if (uid.isEmpty) {
        throw Exception('User created but no ID returned');
      }

      final Map<String, dynamic> userData = {
        'email': email,
        'password': 'password',
        'name': fullName,
        'role': 'Staff',
        'status': 'Active',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'entity': '',
        'department': '',
        'designation': '',
        if (adminEmail.isNotEmpty) 'admin': {'approved': adminEmail},
      };

      final Map<String, dynamic> onboardingData = {
        'user_id': uid,
        'email': email,
        'name': firstName,
        'surname': lastName,
        'fullName': fullName.trim(),
        'department': '',
        'designation': '',
        'status': 'Active',
        'role': 'Staff',
        'first_valid': DateTime.utc(2025, 9, 25).toIso8601String(),
        'inserted_by': adminEmail.isNotEmpty ? adminEmail : email,
        'last_valid': DateTime.utc(2039, 12, 31).toIso8601String(),
        'onboarding_id': uid,
        'status_id': '',
        if (adminEmail.isNotEmpty) 'admin': {'approved': adminEmail},
      };

      try {
        await syncUserToPDH(userData, onboardingData, uid);
      } catch (e) {
        debugPrint('PDH sync failed for new user: $e');
      }

      try {
        await syncUserToSkillsHeatmap(userData, onboardingData, uid);
      } catch (e) {
        debugPrint('Skills Heatmap sync failed for new user: $e');
      }

      if (!skipRefresh && mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchUsers(forceRefresh: true);

        if (mounted) {
          SoundSystem.playSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User $fullName created successfully!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: appTextColor(context),
                ),
              ),
              backgroundColor: const Color(0xFFC10D00),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating new user: $e');
      rethrow;
    }
  }

  void _showBulkUpdateDialog(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final selectedUsers = userProvider.users
        .where((u) => _selectedUserIds.contains(u.id))
        .toList();
    if (selectedUsers.isEmpty) return;
    final first = selectedUsers.first;
    final deptOptions = _availableDepartments;
    final desigOptions = _availableDesignations;

    String? bulkRole = first.role;
    String? bulkStatus = first.status;
    String? bulkDepartment;
    String? bulkDesignation;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color dialogBg = isDark
                ? const Color(0xFF3D3F40)
                : Colors.white;
            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                'Bulk update',
                style: TextStyle(
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Apply the following to ${selectedUsers.length} selected user(s):',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 13.0,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'Role',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: userRoles.contains(bulkRole) ? bulkRole : null,
                        isExpanded: true,
                        dropdownColor: dialogBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                        ),
                        items: userRoles
                            .map(
                              (r) => DropdownMenuItem<String>(
                                value: r,
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    color: appTextColor(context),
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          SoundSystem.playButtonClick();
                          setDialogState(() => bulkRole = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Status',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: userStatusColors.containsKey(bulkStatus)
                            ? bulkStatus
                            : null,
                        isExpanded: true,
                        dropdownColor: dialogBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                        ),
                        items: userStatusColors.keys
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    color: appTextColor(context),
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          SoundSystem.playButtonClick();
                          setDialogState(() => bulkStatus = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Department (optional)',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: bulkDepartment,
                        isExpanded: true,
                        dropdownColor: dialogBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                        ),
                        hint: Text(
                          '— No change —',
                          style: TextStyle(color: appTextColor(context)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— No change —'),
                          ),
                          ...deptOptions.map(
                            (d) => DropdownMenuItem<String?>(
                              value: d,
                              child: Text(
                                d,
                                style: TextStyle(
                                  color: appTextColor(context),
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          SoundSystem.playButtonClick();
                          setDialogState(() => bulkDepartment = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    Text(
                      'Designation (optional)',
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: bulkDesignation,
                        isExpanded: true,
                        dropdownColor: dialogBg,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                        ),
                        hint: Text(
                          '— No change —',
                          style: TextStyle(color: appTextColor(context)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— No change —'),
                          ),
                          ...desigOptions.map(
                            (d) => DropdownMenuItem<String?>(
                              value: d,
                              child: Text(
                                d,
                                style: TextStyle(
                                  color: appTextColor(context),
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          SoundSystem.playButtonClick();
                          setDialogState(() => bulkDesignation = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    SoundSystem.playButtonClick();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: appTextColor(context),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    SoundSystem.playButtonClick();
                    Navigator.of(ctx).pop();
                    final role = bulkRole ?? first.role;
                    final status = bulkStatus ?? first.status;
                    int done = 0;
                    int failed = 0;
                    for (final user in selectedUsers) {
                      try {
                        await _updateUserRoleAndStatus(
                          user.id,
                          role,
                          status,
                          oldRole: user.role,
                          oldStatus: user.status,
                          firstName: user.firstName,
                          lastName: user.lastName,
                          department: bulkDepartment ?? user.department,
                          designation: bulkDesignation ?? user.designation,
                          entity: user.entity,
                        );
                        done++;
                      } catch (_) {
                        failed++;
                      }
                    }
                    if (mounted) {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedUserIds.clear();
                      });
                      final currentContext = context;
                      if (!currentContext.mounted) return;
                      if (done > 0) SoundSystem.playSuccess();
                      if (failed > 0) SoundSystem.playError();
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Updated $done user(s).${failed > 0 ? ' $failed failed.' : ''}',
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                          backgroundColor: const Color(0xFFC10D00),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: appTextColor(context),
                  ),
                  child: Text(
                    'Save',
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

  void _showDeleteConfirmation(BuildContext context) {
    final selectedCount = _selectedUserIds.length;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color dialogBg = isDark
            ? const Color(0xFF3D3F40)
            : Colors.white;
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(
            'Delete Users',
            style: TextStyle(
              color: appTextColor(context),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete $selectedCount user(s)?',
            style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SoundSystem.playButtonClick();
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                SoundSystem.playButtonClick();
                Navigator.of(context).pop();
                _deleteUsers(_selectedUserIds.toList());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: appTextColor(context),
              ),
              child: Text(
                'Delete',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUsers(List<String> userIds) async {
    if (userIds.isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    setState(() {
      _isSelectionMode = false;
      if (expandedUserId != null && userIds.contains(expandedUserId)) {
        expandedUserId = null;
      }
      _selectedUserIds.clear();
    });

    int failureCount = 0;
    final List<String> failedUserIds = [];
    final List<String> successfullyDeletedUserIds = [];
    final List<String> errorMessages = [];

    const int batchSize = 10;
    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();

      final results = await Future.wait(
        batch.map((userId) async {
          try {
            await _deleteUser(userId);
            return {'success': true, 'userId': userId, 'error': null};
          } catch (e) {
            debugPrint('Failed to delete user $userId: $e');
            return {'success': false, 'userId': userId, 'error': e.toString()};
          }
        }),
        eagerError: false,
      );

      for (final result in results) {
        if (result['success'] as bool) {
          successfullyDeletedUserIds.add(result['userId'] as String);
        } else {
          failureCount++;
          failedUserIds.add(result['userId'] as String);
          errorMessages.add(result['error'] as String? ?? 'Unknown error');
        }
      }

      if (i + batchSize < userIds.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Only remove users from UI after successful API deletion
    if (successfullyDeletedUserIds.isNotEmpty) {
      userProvider.removeUsers(successfullyDeletedUserIds);
    }

    if (failureCount > 0 &&
        failedUserIds.isNotEmpty &&
        errorMessages.isNotEmpty) {
      debugPrint(
        'Failed to delete $failureCount user(s): ${failedUserIds.join(', ')}. '
        'Errors: ${errorMessages.join(' | ')}',
      );
    }

    // Show feedback to user
    if (mounted) {
      String message = '';
      if (successfullyDeletedUserIds.isNotEmpty) {
        message +=
            'Successfully deleted ${successfullyDeletedUserIds.length} user(s).';
      }
      if (failureCount > 0) {
        message += ' Failed to delete $failureCount user(s).';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(fontFamily: 'Poppins', color: appTextColor(context)),
          ),
          backgroundColor: successfullyDeletedUserIds.isNotEmpty
              ? (failureCount > 0 ? Colors.orange : Colors.green)
              : Colors.red,
        ),
      );
    }

    if (successfullyDeletedUserIds.isNotEmpty) {
      await _publishAdminAlert(
        title: 'Users deleted',
        message:
            '${successfullyDeletedUserIds.length} user(s) deleted by admin.',
        details: {
          'deletedUserIds': successfullyDeletedUserIds,
          'failedCount': failureCount,
        },
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.deleteUserEndpoint(userId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorBody = response.body;
        throw Exception(
          'Failed to delete user: ${response.statusCode} - $errorBody',
        );
      }

      debugPrint('Successfully deleted user $userId');
    } catch (e) {
      debugPrint('Error deleting user $userId: $e');
      rethrow;
    }
  }
}
