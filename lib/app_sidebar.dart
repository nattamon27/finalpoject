import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onMenuSelected;
  final String userName;
  final String userRole;
  final String? userAvatarUrl; // URL รูปโปรไฟล์ (ถ้ามี)

  const AppSidebar({
    Key? key,
    required this.selectedIndex,
    required this.onMenuSelected,
    required this.userName,
    required this.userRole,
    this.userAvatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 0,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          FontAwesomeIcons.tractor,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'FarmRental',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context); // ปิด drawer
                    },
                  ),
                ],
              ),
            ),

            // User Profile
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      image:
                          userAvatarUrl != null && userAvatarUrl!.isNotEmpty
                              ? DecorationImage(
                                image: NetworkImage(userAvatarUrl!),
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        userRole,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Menu Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'เมนูหลัก',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  _buildMenuItem(
                    context,
                    icon: FontAwesomeIcons.gaugeHigh,
                    title: 'แดชบอร์ด',
                    index: 0,
                  ),
                  _buildMenuItem(
                    context,
                    icon: FontAwesomeIcons.calendarAlt,
                    title: 'การจอง',
                    index: 1,
                  ),
                  _buildMenuItem(
                    context,
                    icon: FontAwesomeIcons.tractor,
                    title: 'พาหนะ',
                    index: 2,
                  ),
                  _buildMenuItem(
                    context,
                    icon: FontAwesomeIcons.user,
                    title: 'ข้อมูลส่วนตัว',
                    index: 3,
                  ),
                  _buildMenuItem(
                    context,
                    icon: FontAwesomeIcons.headset,
                    title: 'ติดต่อผู้ดูแลระบบ',
                    index: 4,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Logout Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: _buildMenuItem(
                context,
                icon: FontAwesomeIcons.signOutAlt,
                title: 'ออกจากระบบ',
                index: 5,
                isLogout: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    bool isLogout = false,
  }) {
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onMenuSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    isLogout
                        ? Colors.red
                        : isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color:
                      isLogout
                          ? Colors.red
                          : isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[800],
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
