import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/auth_state_notifier.dart';
import '../../../core/theme/app_colors.dart';

class UserProfileView extends StatelessWidget {
  const UserProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authStateNotifier,
      builder: (context, _) {
        final role = authStateNotifier.role;
        final user = authStateNotifier.user;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1E2128), AppColors.surface],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (user?.email?.isNotEmpty == true)
                                ? user!.email![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user?.email ?? 'My Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        if (role == 'admin') ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Administrator',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                title: const Text(
                  'Profile',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Main Navigation ────────────────────────────────
                      _ProfileSection(
                        title: 'My Activity',
                        items: [
                          _ProfileItem(
                            icon: Icons.event_rounded,
                            label: 'My Events',
                            onTap: () => context.push('/my-events'),
                          ),
                          _ProfileItem(
                            icon: Icons.smart_toy_rounded,
                            label: 'AI Event Planner',
                            onTap: () => context.push('/ai-planner'),
                          ),
                          _ProfileItem(
                            icon: Icons.explore_rounded,
                            label: 'Browse Venues',
                            onTap: () => context.push('/venues'),
                          ),
                          _ProfileItem(
                            icon: Icons.storefront_rounded,
                            label: 'Browse Vendors',
                            onTap: () => context.push('/vendors'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Account Settings ──────────────────────────────
                      _ProfileSection(
                        title: 'Account',
                        items: [
                          _ProfileItem(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Link WhatsApp',
                            subtitle: 'Plan events via WhatsApp',
                            onTap: () => context.push('/link-whatsapp'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Admin Dashboard ── Visible ONLY to admin accounts ──
                      // Role is verified from Firebase Custom Claims (server-assigned).
                      // Normal users and vendors cannot see this section.
                      if (role == 'admin') ...[
                        _ProfileSection(
                          title: 'Administration',
                          items: [
                            _ProfileItem(
                              icon: Icons.admin_panel_settings_rounded,
                              label: 'Admin Dashboard',
                              subtitle: 'Manage vendors, events and platform',
                              onTap: () => context.push('/admin'),
                              accent: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Sign Out ──────────────────────────────────────
                      _ProfileSection(
                        title: 'Session',
                        items: [
                          _ProfileItem(
                            icon: Icons.logout_rounded,
                            label: 'Sign Out',
                            onTap: () async {
                              await FirebaseAuthService.signOut();
                            },
                            destructive: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileItem> items;

  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  item,
                  if (idx < items.length - 1)
                    Divider(
                      height: 1,
                      color: AppColors.glassBorder,
                      indent: 56,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool accent;

  const _ProfileItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.red
        : accent
            ? AppColors.primary
            : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (destructive
                        ? Colors.red
                        : accent
                            ? AppColors.primary
                            : AppColors.glassBorder)
                    .withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
