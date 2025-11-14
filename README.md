# Platform Implementation Test App

This is a test app for manual testing and automated integration testing
of this platform implementation. It is not intended to demonstrate actual use of
this package, since the intent is that plugin clients use the app-facing
package.

Unless you are making changes to this implementation package, this example is
very unlikely to be relevant.

# How to Restore Hidden Side Menu Items

To restore the hidden items in the side navigation bar, you need to edit the `lib/widgets/side_menu.dart` file.

Follow these steps:

1.  Open the file `lib/widgets/side_menu.dart`.
2.  Locate the `children` array inside the `ListView` widget within the `build` method of the `_SideMenuState` class.
3.  You will find a commented-out block of `MenuItemWidget`s.
4.  To restore any of the items, you can uncomment them.

Here is the block of code that is currently commented out:

```dart
/*
MenuItemWidget(
  unselectedIconPath: 'assets/images/Project Launch_Start/Project Launch_Start_White Badge_Red.png',
  selectedIconPath: 'assets/images/Project Launch_Start/Project Launch_Start_White Badge_Red.png',
  title: 'Dashboard',
  isSelected: widget.selectedIndex == 0,
  isExpanded: _isExpanded,
  onTap: () => widget.onItemSelected(0),
),
MenuItemWidget(
  unselectedIconPath: 'assets/images/Networking_Collaboration/Networking_Collaboration_White Badge__Red.png',
  selectedIconPath: 'assets/images/Networking_Collaboration/Collaboration_Red Badge_White.png',
  title: 'Resource Allocation',
  isSelected: widget.selectedIndex == 1,
  isExpanded: _isExpanded,
  onTap: () => widget.onItemSelected(1),
),
MenuItemWidget(
  unselectedIconPath: 'assets/images/Time Allocation_Approval/Time Allocation_Approval_White Badge_Red.png',
  selectedIconPath: 'assets/images/Time Allocation_Approval/Allocation_Red Badge_White.png',
  title: 'Time Keeping',
  isSelected: widget.selectedIndex == 2,
  isExpanded: _isExpanded,
  onTap: () => widget.onItemSelected(2),
),
MenuItemWidget(
  unselectedIconPath: 'assets/images/Project Management/Project Management_White Badge_Red.png',
  selectedIconPath: 'assets/images/Project Management/Project_Red Badge_White.png',
  title: 'Project Data',
  isSelected: widget.selectedIndex == 3,
  isExpanded: _isExpanded,
  onTap: () => widget.onItemSelected(3),
),
MenuItemWidget(
  unselectedIconPath: 'assets/images/Business Growth_Development/Business Growth_Development_White Badge_Red.png',
  selectedIconPath: 'assets/images/Business Growth_Development/Growth_Development_Red Badge_White.png',
  title: 'Analytics',
  isSelected: widget.selectedIndex == 4,
  isExpanded: _isExpanded,
  onTap: () => widget.onItemSelected(4),
),
MenuItemWidget(
  unselectedIconPath: 'assets/images/Account_User Profile/User Profile_White Badge_Red.png',
  selectedIconPath: 'assets/images/Account_User Profile/red_user_profile.png',
  title: 'Profile',
  isSelected: widget.selectedIndex == 5,
  isExpanded: _isExpanded,
  onTap: () => widget.onItemSelected(5),
),
*/
```