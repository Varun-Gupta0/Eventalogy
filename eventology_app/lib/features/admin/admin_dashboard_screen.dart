import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/firestore_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            onPressed: () => context.go('/'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Enquiries'),
            Tab(text: 'Checklist'),
            Tab(text: 'Allocations'),
          ],
        ),
      ),
      body: Stack(
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
              // Metrics Summary Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surfaceLighter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Pending', '12', AppColors.primary),
                    _buildMetric('Allocated', '28', Colors.greenAccent),
                    _buildMetric('Vendors', '140+', Colors.blueAccent),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEnquiriesTab(),
                    _buildChecklistTab(),
                    _buildAllocationsTab(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEnquiriesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.getCategories(),
      builder: (context, snapshot) {
        final mockEnquiries = [
          {
            'client': 'Rahul & Ananya',
            'event': 'Royal Wedding',
            'budget': '₹25,00,000',
            'date': '15 Dec 2026',
            'status': 'Pending Verification'
          },
          {
            'client': 'TechCorp Ltd',
            'event': 'Annual Tech Gala',
            'budget': '₹12,00,000',
            'date': '20 Nov 2026',
            'status': 'Vendor Allocation'
          },
          {
            'client': 'Vikram Sharma',
            'event': '50th Milestone Birthday',
            'budget': '₹5,50,000',
            'date': '05 Oct 2026',
            'status': 'Confirmed'
          },
        ];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mockEnquiries.length,
          itemBuilder: (context, index) {
            final item = mockEnquiries[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['event']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item['status']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Client: ${item['client']} • Date: ${item['date']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget: ${item['budget']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.background,
                            ),
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChecklistTab() {
    final checklist = [
      {'task': 'Verify Host Identity & Contact', 'done': true},
      {'task': 'Confirm Venue Availability & Deposit', 'done': true},
      {'task': 'Finalize Catering Menu & Guest Count', 'done': false},
      {'task': 'Assign Sound & Stage Production Team', 'done': false},
      {'task': 'Security & Traffic Clearance', 'done': false},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: checklist.length,
      itemBuilder: (context, index) {
        final item = checklist[index];
        final isDone = item['done'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: CheckboxListTile(
            activeColor: AppColors.primary,
            checkColor: AppColors.background,
            value: isDone,
            title: Text(
              item['task'] as String,
              style: TextStyle(
                color: isDone ? AppColors.textSecondary : Colors.white,
                decoration:
                    isDone ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                item['done'] = val ?? false;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildAllocationsTab() {
    final vendors = [
      {'name': 'Starlight Decorators', 'type': 'Decor & Stage', 'rating': '4.9 ★'},
      {'name': 'Royal Feast Caterers', 'type': 'Catering', 'rating': '4.8 ★'},
      {'name': 'Apex DJ & Lighting', 'type': 'Sound & Light', 'rating': '5.0 ★'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vendors.length,
      itemBuilder: (context, index) {
        final v = vendors[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store, color: AppColors.primary),
            ),
            title: Text(
              v['name']!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${v['type']} • Rating: ${v['rating']}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLighter,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Assign Event'),
            ),
          ),
        );
      },
    );
  }
}
