import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/landing_screen.dart';
import 'version_control_widget.dart'; // Added import for VersionControlWidget

class MenuItemWidget extends StatefulWidget {
  final String unselectedIconPath;
  final String selectedIconPath;
  final String title;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback? onTap;

  const MenuItemWidget({
    super.key,
    required this.unselectedIconPath,
    required this.selectedIconPath,
    required this.title,
    required this.isSelected,
    required this.isExpanded,
    this.onTap,
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

  // Text style
  TextStyle get textStyle => const TextStyle(
    fontFamily: 'Poppins', // Added Poppins font
    color: Colors.white,
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    // Determine which icon to show based on selection state
    final String currentIconPath = widget.isSelected
        ? widget.selectedIconPath
        : widget.unselectedIconPath;

    return MouseRegion(
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
          onTap: widget.onTap,
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
                        child: Text(
                          widget.title,
                          style: textStyle,
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.visible,
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

  // Responsive text style
  TextStyle get textStyle {
    double fontSize = isMobile ? 14.0 : (isTablet ? 15.0 : 16.0);
    return TextStyle(
      color: _isHovering ? const Color(0xFFC10D00) : Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onTap: widget.onTap,
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
                            color: _isHovering
                                ? const Color(0xFFC10D00)
                                : Colors.white, // Red on hover, white normally
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
                          style: textStyle,
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
  bool _isExpanded = false;

  // Fixed sidebar widths per design spec
  double get sidebarWidth => _isExpanded ? 260 : 64;

  // Check if current user is Admin
  bool get _isAdmin {
    final authProvider = context.read<AuthProvider>();
    final role = authProvider.userRole?.toLowerCase() ?? '';
    return role == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    // No auto-collapse; fixed widths handle layout consistently

    return Container(
      width: sidebarWidth,
      color: const Color(0xFF1F2840),
      child: Column(
        children: [
          // Header with toggle button
          Container(
            decoration: const BoxDecoration(color: Color(0xFF1F2840)),
            child: Column(
              children: [
                // Toggle button row - Fixed overflow issue
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: InkWell(
                          // Wrap the Image.asset with InkWell
                          onTap: () {
                            // Transfer onPressed logic here
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Center(
                            child: Image.asset(
                              _isExpanded
                                  ? 'assets/images/khono.png'
                                  : 'assets/images/discs.png',
                              height: _isExpanded ? 40 : 32,
                              width: _isExpanded ? null : 32,
                              fit: _isExpanded
                                  ? BoxFit.contain
                                  : BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Removed IconButton
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // User Management - Admin only
                if (_isAdmin)
                  MenuItemWidget(
                    unselectedIconPath:
                        'assets/images/HR_Team_Management/Management_White_Badge_Red.png',
                    selectedIconPath:
                        'assets/images/HR_Team_Management/red_Management_Red_Badge_White.png',
                    title: 'User Management',
                    isSelected: widget.selectedIndex == 0,
                    isExpanded: _isExpanded,
                    onTap: () => widget.onItemSelected(0),
                  ),
                // Entity Management - Admin only
                if (_isAdmin)
                  MenuItemWidget(
                    unselectedIconPath:
                        'assets/images/Task_Management/Task_White Badge_Red.png',
                    selectedIconPath:
                        'assets/images/Task_Management/Task_Red Badge_White.png',
                    title: 'Entity Management',
                    isSelected: widget.selectedIndex == 1,
                    isExpanded: _isExpanded,
                    onTap: () => widget.onItemSelected(1),
                  ),
                // Module Access - Admin only
                if (_isAdmin)
                  MenuItemWidget(
                    unselectedIconPath:
                        'assets/images/Concentration_Key_Focus/Concentration_Key_Focus_White_Badge_Red.png',
                    selectedIconPath:
                        'assets/images/Concentration_Key_Focus/Concentration_Key_Focus_Red_Badge_White.png',
                    title: 'Module Access',
                    isSelected: widget.selectedIndex == 2,
                    isExpanded: _isExpanded,
                    onTap: () => widget.onItemSelected(2),
                  ),
                // Modules - Available to all users (Staff and Admin)
                MenuItemWidget(
                  unselectedIconPath:
                      'assets/images/Project Launch_Start/Project Launch_Start_White Badge_Red.png',
                  selectedIconPath:
                      'assets/images/Project Launch_Start/Project Launch_Start_White Badge_Red.png',
                  title: 'Modules',
                  isSelected: widget.selectedIndex == 3,
                  isExpanded: _isExpanded,
                  onTap: () => widget.onItemSelected(3),
                ),
                // Small spacing before logout button
                const SizedBox(height: 310.0),
                // Version Control Widget positioned above logout button - only show when expanded
                if (_isExpanded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Center(
                      child: const VersionControlWidget(
                        fontSize: 10.0, // Smaller font for sidebar
                      ),
                    ),
                  ),
                // Logout item with hover functionality - directly below version control
                _LogoutMenuItem(
                  isExpanded: _isExpanded,
                  onTap: () {
                    context.read<AuthProvider>().logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LandingScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
