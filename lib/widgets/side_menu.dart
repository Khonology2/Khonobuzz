// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/landing_screen.dart';
import '../services/sound_system.dart';
import 'version_control_widget.dart'; // Added import for VersionControlWidget

const Color _sideMenuDarkWidgetColor = Color(0xFF3D3F40);

class MenuItemWidget extends StatefulWidget {
  final String unselectedIconPath;
  final String selectedIconPath;
  final String title;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback? onTap;
  /// Optional key for E2E (e.g. Modules / Profile).
  final Key? itemKey;

  const MenuItemWidget({
    super.key,
    required this.unselectedIconPath,
    required this.selectedIconPath,
    required this.title,
    required this.isSelected,
    required this.isExpanded,
    this.onTap,
    this.itemKey,
  });

  @override
  State<MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<MenuItemWidget> {
  bool _isHovering = false;

  // Fixed sizes per design spec

  // Icon container sizing
  double get iconSize => widget.isExpanded ? 40 : 32;

  // Padding
  EdgeInsets get itemPadding => widget.isExpanded
      ? const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0)
      : const EdgeInsets.all(12.0);

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final TextStyle itemTextStyle = TextStyle(
      fontFamily: 'Poppins',
      color: widget.isSelected
          ? Colors.white
          : (isLight ? Colors.black : Colors.white),
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
    );

    // Determine which icon to show based on selection state
    final String currentIconPath = widget.isSelected
        ? widget.selectedIconPath
        : widget.unselectedIconPath;

    return Semantics(
      label: widget.title,
      button: true,
      child: KeyedSubtree(
        key: widget.itemKey,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFFC10D00) // Solid red for selected
                  : _isHovering
                  ? const Color(0xFFC10D00).withAlpha(
                      44,
                    ) // Light red for hover (doesn't override selected)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                25,
              ), // Fully rounded circular/pill design
            ),
            child: InkWell(
              onTap: () {
                SoundSystem.playButtonClick();
                widget.onTap?.call();
              },
              borderRadius: BorderRadius.circular(
                25,
              ), // Fully rounded circular/pill design
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool showText =
                      widget.isExpanded && constraints.maxWidth >= 150;
                  final EdgeInsets resolvedPadding = showText
                      ? itemPadding
                      : const EdgeInsets.all(8.0);
                  return Padding(
                    padding: resolvedPadding,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: showText
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        // Icon container with dynamic icon switching
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: Colors
                                .transparent, // Remove individual icon background
                            borderRadius: BorderRadius.circular(
                              25,
                            ), // Fully rounded circular/pill design
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Image.asset(
                                currentIconPath,
                                key: ValueKey(
                                  currentIconPath,
                                ), // Key for smooth animation
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        if (showText) ...[
                          const SizedBox(width: 16),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.title,
                                style: itemTextStyle,
                                softWrap: false,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutMenuItem extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _LogoutMenuItem({required this.isExpanded, required this.onTap});

  @override
  State<_LogoutMenuItem> createState() => _LogoutMenuItemState();
}

class _LogoutMenuItemState extends State<_LogoutMenuItem> {
  bool _isHovering = false;

  // Responsive breakpoints
  bool get isMobile => MediaQuery.of(context).size.width < 768;
  bool get isTablet => MediaQuery.of(context).size.width < 1024;

  // Responsive icon container sizing
  double get iconSize {
    if (isMobile) {
      return widget.isExpanded ? 36 : 28;
    } else if (isTablet) {
      return widget.isExpanded ? 38 : 30;
    } else {
      return widget.isExpanded ? 40 : 32;
    }
  }

  // Responsive icon size
  double get iconIconSize {
    if (isMobile) {
      return widget.isExpanded ? 20 : 16;
    } else if (isTablet) {
      return widget.isExpanded ? 22 : 18;
    } else {
      return widget.isExpanded ? 24 : 20;
    }
  }

  // Responsive padding
  EdgeInsets get itemPadding {
    if (isMobile) {
      return widget.isExpanded
          ? const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0)
          : const EdgeInsets.all(8.0);
    } else if (isTablet) {
      return widget.isExpanded
          ? const EdgeInsets.symmetric(vertical: 11.0, horizontal: 14.0)
          : const EdgeInsets.all(10.0);
    } else {
      return widget.isExpanded
          ? const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0)
          : const EdgeInsets.all(12.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color normalText = isLight ? Colors.black : Colors.white;
    final Color hoverText = const Color(0xFFC10D00);
    final Color normalIcon = isLight ? Colors.black : Colors.white;
    final Color hoverIcon = const Color(0xFFC10D00);

    double fontSize = isMobile ? 14.0 : (isTablet ? 15.0 : 16.0);
    final TextStyle logoutTextStyle = TextStyle(
      color: _isHovering ? hoverText : normalText,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: _isHovering
              ? const Color(0xFFC10D00).withAlpha(44) // Light red for hover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            25,
          ), // Fully rounded circular/pill design
        ),
        child: InkWell(
          onTap: () {
            SoundSystem.playButtonClick();
            widget.onTap();
          },
          borderRadius: BorderRadius.circular(
            25,
          ), // Fully rounded circular/pill design
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool showText =
                  widget.isExpanded && constraints.maxWidth >= 150;
              final EdgeInsets resolvedPadding = showText
                  ? itemPadding
                  : const EdgeInsets.all(8.0);
              return Padding(
                padding: resolvedPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: showText
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          25,
                        ), // Fully rounded circular/pill design
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.logout,
                            color: _isHovering ? hoverIcon : normalIcon,
                            size: iconIconSize,
                          ),
                        ),
                      ),
                    ),
                    if (showText) ...[
                      const SizedBox(width: 16),
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: logoutTextStyle,
                          child: const Text(
                            'Logout',
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  static const double _sidebarWidth = 260;

  // Check if current user is Admin
  bool get _isAdmin {
    final authProvider = context.read<AuthProvider>();
    final role = authProvider.userRole?.toLowerCase() ?? '';
    return role == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color sidebarBg =
        isLight ? Colors.white : _sideMenuDarkWidgetColor;

    return Container(
      width: _sidebarWidth,
      color: sidebarBg,
      child: _buildSidebar(),
    );
  }

  Widget _buildSidebar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLight = !isDark;
    final unselectedColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.84);
    final welcomeTextColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.82);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVeryCompact = constraints.maxHeight < 660;
        final isUltraCompact = constraints.maxHeight < 580;

        final double navVerticalPadding = isUltraCompact
            ? 1.5
            : (isVeryCompact ? 2 : 3);
        final double sectionGap = isUltraCompact ? 2 : (isVeryCompact ? 4 : 6);
        final double bottomGap = isUltraCompact ? 6 : (isVeryCompact ? 8 : 10);

        return Column(
          children: [
            SizedBox(height: isUltraCompact ? 4 : 8),
            Image.asset(
              'assets/images/khono.png',
              width: isUltraCompact ? 150 : (isVeryCompact ? 190 : 228),
              height: isUltraCompact ? 28 : (isVeryCompact ? 35 : 44),
              fit: BoxFit.contain,
            ),
            SizedBox(height: isUltraCompact ? 4 : 6),
            Text(
              'Welcome to KhonoBuzz',
              style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sectionGap),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: navVerticalPadding,
                ),
                child: Column(
                  children: [
                    if (_isAdmin)
                      MenuItemWidget(
                        unselectedIconPath:
                            'assets/images/HR_Team_Management/Management_White_Badge_Red.png',
                        selectedIconPath:
                            'assets/images/HR_Team_Management/red_Management_Red_Badge_White.png',
                        title: 'User Management',
                        isSelected: widget.selectedIndex == 0,
                        isExpanded: true,
                        onTap: () => widget.onItemSelected(0),
                      ),
                    if (_isAdmin)
                      MenuItemWidget(
                        unselectedIconPath:
                            'assets/images/Task_Management/Task_White Badge_Red.png',
                        selectedIconPath:
                            'assets/images/Task_Management/Task_Red Badge_White.png',
                        title: 'Entity Management',
                        isSelected: widget.selectedIndex == 1,
                        isExpanded: true,
                        onTap: () => widget.onItemSelected(1),
                      ),
                    if (_isAdmin)
                      MenuItemWidget(
                        unselectedIconPath:
                            'assets/images/Concentration_Key_Focus/Concentration_Key_Focus_White_Badge_Red.png',
                        selectedIconPath:
                            'assets/images/Concentration_Key_Focus/Concentration_Key_Focus_Red_Badge_White.png',
                        title: 'Module Access',
                        isSelected: widget.selectedIndex == 2,
                        isExpanded: true,
                        onTap: () => widget.onItemSelected(2),
                      ),
                    MenuItemWidget(
                      itemKey: const ValueKey('e2e_nav_modules'),
                      unselectedIconPath:
                          'assets/images/Project Launch_Start/Project Launch_Start_White Badge_Red.png',
                      selectedIconPath:
                          'assets/images/Project Launch_Start/Project Launch_Start_White Badge_Red.png',
                      title: 'Modules',
                      isSelected: widget.selectedIndex == 3,
                      isExpanded: true,
                      onTap: () => widget.onItemSelected(3),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: bottomGap),
            if (isLight || isDark)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: MenuItemWidget(
                  itemKey: const ValueKey('e2e_nav_profile'),
                  unselectedIconPath:
                      'assets/images/HR_Team_Management/Management_White_Badge_Red.png',
                  selectedIconPath:
                      'assets/images/HR_Team_Management/red_Management_Red_Badge_White.png',
                  title: 'Profile',
                  isSelected: widget.selectedIndex == 4,
                  isExpanded: true,
                  onTap: () => widget.onItemSelected(4),
                ),
              ),
            SizedBox(height: bottomGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _LogoutMenuItem(
                isExpanded: true,
                onTap: () async {
                  SoundSystem.playButtonClick();
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      final bool dialogIsLight =
                          Theme.of(dialogContext).brightness == Brightness.light;
                      final Color dialogTextColor = dialogIsLight
                          ? Colors.black
                          : Colors.white;
                      return AlertDialog(
                        backgroundColor: dialogIsLight
                            ? Colors.white
                            : _sideMenuDarkWidgetColor,
                        title: Text(
                          'Confirm logout',
                          style: TextStyle(
                            color: dialogTextColor,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to logout?',
                          style: TextStyle(
                            color: dialogTextColor,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        actions: [
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(false);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: dialogTextColor,
                              side: BorderSide(
                                color: dialogTextColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC10D00),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Yes',
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (shouldLogout != true || !context.mounted) {
                    return;
                  }

                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;

                  context.read<UserProvider>().clearCache();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LandingScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Center(
                child: VersionControlWidget(
                  fontSize: 12.0,
                  textColor: unselectedColor.withValues(alpha: 0.74),
                  hoverColor: unselectedColor,
                ),
              ),
            ),
            SizedBox(height: bottomGap),
          ],
        );
      },
    );
  }
}
