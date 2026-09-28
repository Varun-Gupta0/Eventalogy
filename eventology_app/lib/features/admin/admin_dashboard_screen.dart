import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/firestore/master_data_repository.dart';

import 'admin_locations_tab.dart';
import 'admin_services_tab.dart';
import 'admin_vendors_tab.dart';
import 'admin_venues_tab.dart';
import 'admin_packages_tab.dart';
import 'admin_events_tab.dart';
import 'admin_enquiries_tab.dart';
import 'admin_bookings_tab.dart';
import 'admin_allocations_tab.dart';
import 'admin_payments_tab.dart';
import 'admin_reviews_tab.dart';
import 'admin_notifications_tab.dart';
import 'admin_ai_plans_tab.dart';
import 'admin_ai_recommendations_tab.dart';
import 'admin_agent_tasks_tab.dart';
import 'admin_agent_logs_tab.dart';
import 'admin_audit_logs_tab.dart';
import 'admin_settings_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _tabs = [
    // MASTER DATA
    {'title': 'Locations', 'icon': Icons.location_city, 'widget': const AdminLocationsTab(), 'category': 'MASTER DATA'},
    {'title': 'Services', 'icon': Icons.design_services, 'widget': const AdminServicesTab(), 'category': 'MASTER DATA'},
    {'title': 'Vendors', 'icon': Icons.store, 'widget': const AdminVendorsTab(), 'category': 'MASTER DATA'},
    {'title': 'Venues', 'icon': Icons.business, 'widget': const AdminVenuesTab(), 'category': 'MASTER DATA'},
    {'title': 'Packages', 'icon': Icons.card_giftcard, 'widget': const AdminPackagesTab(), 'category': 'MASTER DATA'},
    // OPERATIONS
    {'title': 'Events', 'icon': Icons.event, 'widget': const AdminEventsTab(), 'category': 'OPERATIONS'},
    {'title': 'Enquiries', 'icon': Icons.help_outline, 'widget': const AdminEnquiriesTab(), 'category': 'OPERATIONS'},
    {'title': 'Bookings', 'icon': Icons.book_online, 'widget': const AdminBookingsTab(), 'category': 'OPERATIONS'},
    {'title': 'Allocations', 'icon': Icons.assignment, 'widget': const AdminAllocationsTab(), 'category': 'OPERATIONS'},
    {'title': 'Payments', 'icon': Icons.payment, 'widget': const AdminPaymentsTab(), 'category': 'OPERATIONS'},
    {'title': 'Reviews', 'icon': Icons.star, 'widget': const AdminReviewsTab(), 'category': 'OPERATIONS'},
    // INTELLIGENCE & SYSTEM
    {'title': 'Notifications', 'icon': Icons.notifications, 'widget': const AdminNotificationsTab(), 'category': 'INTELLIGENCE & SYSTEM'},
    {'title': 'AI Plans', 'icon': Icons.smart_toy, 'widget': const AdminAiPlansTab(), 'category': 'INTELLIGENCE & SYSTEM'},
    {'title': 'AI Recs', 'icon': Icons.recommend, 'widget': const AdminAiRecommendationsTab(), 'category': 'INTELLIGENCE & SYSTEM'},
    {'title': 'Agent Tasks', 'icon': Icons.task, 'widget': const AdminAgentTasksTab(), 'category': 'INTELLIGENCE & SYSTEM'},
    {'title': 'Agent Logs', 'icon': Icons.history, 'widget': const AdminAgentLogsTab(), 'category': 'INTELLIGENCE & SYSTEM'},
    {'title': 'Audit Logs', 'icon': Icons.security, 'widget': const AdminAuditLogsTab(), 'category': 'INTELLIGENCE & SYSTEM'},
    {'title': 'Settings', 'icon': Icons.settings, 'widget': const AdminSettingsTab(), 'category': 'INTELLIGENCE & SYSTEM'},
  ];

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, Map<String, dynamic> tab) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
                : const Border(left: BorderSide(color: Colors.transparent, width: 3)),
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                tab['icon'] as IconData,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tab['title'] as String,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'ADMIN CONTROL CENTER',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dataset_outlined, color: Colors.greenAccent),
            tooltip: 'Seed Master Data',
            onPressed: () async {
              try {
                await MasterDataRepository.seedAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Master data seeded successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error seeding: \$e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 220,
            color: AppColors.surface,
            child: ListView(
              children: [
                _buildCategoryHeader('MASTER DATA'),
                ..._tabs.asMap().entries.where((e) => e.value['category'] == 'MASTER DATA').map((e) => _buildNavItem(e.key, e.value)),
                _buildCategoryHeader('OPERATIONS'),
                ..._tabs.asMap().entries.where((e) => e.value['category'] == 'OPERATIONS').map((e) => _buildNavItem(e.key, e.value)),
                _buildCategoryHeader('INTELLIGENCE & SYSTEM'),
                ..._tabs.asMap().entries.where((e) => e.value['category'] == 'INTELLIGENCE & SYSTEM').map((e) => _buildNavItem(e.key, e.value)),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1, color: AppColors.surfaceLighter),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: AppColors.surfaceLighter,
                      child: Text(
                        _tabs[_selectedIndex]['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _tabs[_selectedIndex]['widget'],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
