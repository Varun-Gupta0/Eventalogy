import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../vendor_session.dart';

class VendorShellScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const VendorShellScreen({super.key, required this.navigationShell});

  static _VendorShellScreenState of(BuildContext context) {
    return context.findAncestorStateOfType<_VendorShellScreenState>()!;
  }

  @override
  State<VendorShellScreen> createState() => _VendorShellScreenState();
}

class _VendorShellScreenState extends State<VendorShellScreen> {
  void changeTab(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VendorAuthWrapper(
      child: Scaffold(
        extendBody: true,
        body: widget.navigationShell,
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.95),
                border: const Border(
                  top: BorderSide(color: AppColors.glassBorder, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                  _buildNavItem(1, Icons.assignment_rounded, 'Enquiries'),
                  _buildNavItem(2, Icons.event_available_rounded, 'Bookings'),
                  _buildNavItem(3, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = widget.navigationShell.currentIndex == index;
    return GestureDetector(
      onTap: () => changeTab(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
