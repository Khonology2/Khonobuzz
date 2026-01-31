import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/staff_profile_screen.dart';
import '../screens/admin_profile_screen.dart';

class ProfileIcon extends StatefulWidget {
  final bool hasOnboardingAlerts;
  
  const ProfileIcon({super.key, this.hasOnboardingAlerts = false});

  @override
  State<ProfileIcon> createState() => _ProfileIconState();
}

class _ProfileIconState extends State<ProfileIcon> {
  bool _isHovering = false;

  String _formatDisplayName(String fullName) {
    final nameParts = fullName.trim().split(' ');
    
    if (nameParts.isEmpty) {
      return 'User';
    }
    
    if (nameParts.length == 1) {
      // Only one name part, return as is
      return nameParts[0];
    }
    
    // Multiple name parts, format as "R.Nkosinathi"
    final firstName = nameParts[0];
    final lastName = nameParts.sublist(1).join(' ');
    
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final formattedLastName = lastName.isNotEmpty ? lastName : '';
    
    return '$firstInitial.$formattedLastName';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    
    // Get current user from the users list
    final currentUser = userProvider.users.where(
      (user) => user.email == authProvider.userEmail,
    ).firstOrNull;
    
    final fullName = currentUser?.name ?? authProvider.userEmail?.split('@')[0] ?? 'User';
    final displayName = _formatDisplayName(fullName);

    return Positioned(
      top: widget.hasOnboardingAlerts ? 80 : 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final authProvider = context.read<AuthProvider>();
            final userRole = authProvider.userRole?.toLowerCase() ?? '';
            
            if (userRole == 'admin') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StaffProfileScreen()),
              );
            }
          },
          onHover: (hovering) {
            setState(() {
              _isHovering = hovering;
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovering 
                  ? const Color(0xFFD41A0A) 
                  : const Color(0xFFC10D00),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
