// ignore_for_file: unused_import

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
import '../theme/app_backgrounds.dart';
import '../providers/theme_mode_provider.dart';
import '../theme/app_text_colors.dart';
import '../theme/app_themes.dart';

class EntityManagementScreen extends StatefulWidget {
  const EntityManagementScreen({super.key});

  @override
  State<EntityManagementScreen> createState() => _EntityManagementScreenState();
}

class _EntityManagementScreenState extends State<EntityManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _entityOptions = ['Khonology Internal'];
  static const String _notAssignedValue = 'Not Assigned';
  static const Color _popupDarkBg = Color(0xFF3D3F40);
  static final Color entityDarkWidgetBg = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.10),
    const Color(0xFF3D3F40).withValues(alpha: 0.40),
  );

  String? expandedUserId;
  String? _updatingUserId;
  String? _hoveredUserId;
  Timer? _debounceTimer;
  String _searchQuery = '';

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

  List<ManagedUser> get _filteredUsers {
    final userProvider = Provider.of<UserProvider>(context);
    final users = userProvider.users;
    final query = _searchQuery.toLowerCase();

    if (query.isEmpty) return users;

    return users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.department.toLowerCase().contains(query) ||
          user.designation.toLowerCase().contains(query) ||
          (user.entity ?? '').toLowerCase().contains(query);
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
    unawaited(_loadEntityOptions());
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

  Future<void> _loadEntityOptions() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.entitiesEndpoint),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = (decoded['entities'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _entityOptions
          ..clear()
          ..addAll(entities.isNotEmpty ? entities : ['Khonology Internal']);
      });
    } catch (_) {
      // Keep existing options silently if API is unavailable.
    }
  }

  Future<void> _showAddEntityDialog() async {
    final controller = TextEditingController();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dialogBg = isDark ? _popupDarkBg : Colors.white;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(
            'Add new entity',
            style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
            decoration: InputDecoration(
              labelText: 'Entity name',
              labelStyle: TextStyle(color: appTextColor(context)),
            ),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SoundSystem.playButtonClick();
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancel', style: TextStyle(color: appTextColor(context))),
            ),
            ElevatedButton(
              onPressed: () {
                SoundSystem.playButtonClick();
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
              ),
              child: const Text('Add', style: TextStyle(fontFamily: 'Poppins')),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final entityName = result?.trim() ?? '';
    if (entityName.isEmpty) return;

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.entitiesEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': entityName}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to add entity');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = (decoded['entities'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _entityOptions
          ..clear()
          ..addAll(entities.isNotEmpty ? entities : ['Khonology Internal']);
      });
      SoundSystem.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Entity "$entityName" added successfully.',
            style: const TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: const Color(0xFFC10D00),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      SoundSystem.playError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to add entity. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateUserEntity(ManagedUser user, String? newEntity) async {
    final adminEmail = context.read<AuthProvider>().userEmail?.trim() ?? '';
    setState(() {
      _updatingUserId = user.id;
    });

    final sanitizedEntity =
        (newEntity != null &&
            newEntity.trim().isNotEmpty &&
            newEntity != _notAssignedValue)
        ? newEntity.trim()
        : '';
    try {
      final response = await http.patch(
        Uri.parse(ApiConfig.userEndpoint(user.id)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': user.role,
          'status': user.status,
          'entity': sanitizedEntity,
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
      final updatedEntity = backendUser != null
          ? (backendUser['entity'] as String?)?.isNotEmpty == true
                ? backendUser['entity'] as String
                : null
          : (sanitizedEntity.isEmpty ? null : sanitizedEntity);

      setState(() {
        user.entity = updatedEntity;
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
          {'entity': updatedEntity, if (adminField != null) ...adminField},
          onboardingFields: {
            'entity': updatedEntity,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('PDH sync failed for entity update: $e');
        if (mounted) {
          SoundSystem.playError();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Entity updated, but failed to sync with PDH.',
                style: TextStyle(fontFamily: 'Poppins', color: appTextColor(context)),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      try {
        await updateSkillsHeatmapUserPartial(
          user.id,
          {'entity': updatedEntity, if (adminField != null) ...adminField},
          onboardingFields: {
            'entity': updatedEntity,
            if (adminField != null) ...adminField,
          },
        );
      } catch (e) {
        debugPrint('Skills Heatmap sync failed for entity update: $e');
      }

      if (mounted) {
        SoundSystem.playSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Entity updated for ${user.name}.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: appTextColor(context),
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
              'Failed to update entity. Please try again.',
              style: TextStyle(fontFamily: 'Poppins'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        _buildSearch(),
                        const SizedBox(height: 16.0),
                        _buildUserList(),
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
                'Entity Management',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final isLight =
                    Theme.of(context).brightness == Brightness.light;
                return OutlinedButton.icon(
                  onPressed: _showAddEntityDialog,
                  icon: Icon(
                    Icons.add,
                    color: isLight ? Colors.black : Colors.white,
                  ),
                  label: Text(
                    'Add Entity',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isLight ? Colors.black : Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isLight ? Colors.black : Colors.white,
                    side: BorderSide(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
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
          'Assign entities to keep user records up to date.',
          style: TextStyle(
            color: appTextColor(context),
            fontSize: 14.0,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color filledBg = isDark
        ? entityDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search users',
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
        fillColor: filledBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25.0),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
      ),
      style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFC10D00)),
            const SizedBox(height: 24.0),
            Text(
              'Fetching user records...',
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
                    'Failed to load users. please try again later.',
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
      return Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: appTextColor(context), fontFamily: 'Poppins'),
        ),
      );
    }

    return Column(
      children: _filteredUsers.map((user) {
        final isExpanded = expandedUserId == user.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            children: [
              _buildUserRow(user, isExpanded),
              if (isExpanded) _buildEntityPanel(user),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserRow(ManagedUser user, bool isExpanded) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color widgetBg = isDark
        ? entityDarkWidgetBg
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
        child: InkWell(
          onTap: () {
            SoundSystem.playButtonClick();
            setState(() {
              expandedUserId = isExpanded ? null : user.id;
            });
          },
          borderRadius: BorderRadius.circular(16.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: widgetBg,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
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
            final spacingWidth = 8.0 * 2;
            final columnWidth = (availableWidth - spacingWidth) / 3;
            final leftPadding = columnWidth * 0.12;

            final secondColumnWidth = columnWidth - leftPadding;

            return Row(
              children: [
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
                      Flexible(child: _buildEntityChip(user.entity)),
                      const SizedBox(width: 8.0),
                      Transform.rotate(
                        angle: isExpanded ? 3.14 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: appTextColor(context),
                        ),
                      ),
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

  Widget _buildEntityChip(String? entity) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color chipBg = isDark
        ? entityDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);
    final displayText = (entity == null || entity.isEmpty)
        ? _notAssignedValue
        : entity;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: appTextColor(context).withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          color: appTextColor(context),
        ),
      ),
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

  Widget _buildEntityPanel(ManagedUser user) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelBg = isDark
        ? entityDarkWidgetBg
        : Colors.white.withValues(alpha: 0.40);
    final Color popupBg = isDark ? _popupDarkBg : Colors.white;
    final Color dividerColor = appTextColor(context).withValues(
      alpha: isDark ? 0.22 : 0.30,
    );
    String? selectedEntity = (user.entity == null || user.entity!.isEmpty)
        ? _notAssignedValue
        : user.entity;
    final isUpdating = _updatingUserId == user.id;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Entity Assignment',
                style: TextStyle(
                  color: appTextColor(context),
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
              if (isUpdating)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(appTextColor(context)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8.0),
          Divider(color: dividerColor, thickness: 1),
          const SizedBox(height: 8.0),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: DropdownButton<String?>(
                value: selectedEntity,
                isExpanded: true,
                dropdownColor: popupBg,
                icon: Icon(Icons.arrow_drop_down, color: appTextColor(context)),
                style: TextStyle(
                  color: appTextColor(context),
                  fontFamily: 'Poppins',
                ),
                onChanged: isUpdating
                    ? null
                    : (value) async {
                        SoundSystem.playButtonClick();
                        final newEntity = value == _notAssignedValue
                            ? null
                            : value;
                        if (newEntity != user.entity) {
                          await _updateUserEntity(user, newEntity);
                        }
                      },
                items: <DropdownMenuItem<String?>>[
                  DropdownMenuItem<String?>(
                    value: _notAssignedValue,
                    child: Text(
                      _notAssignedValue,
                      style: TextStyle(
                        color: appTextColor(context),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ..._entityOptions.map(
                    (option) => DropdownMenuItem<String?>(
                      value: option,
                      child: Text(
                        option,
                        style: TextStyle(
                          color: appTextColor(context),
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
