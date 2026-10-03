import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/user/shell/user_shell_screen.dart';
import '../../features/user/home/user_home_view.dart';
import '../../features/user/planner/user_planner_view.dart';
import '../../features/user/planner/event_planner_screen.dart';
import '../../features/user/profile/user_profile_view.dart';
import '../../features/user/ai/screens/ai_chat_screen.dart';
import '../../features/user/ai/screens/ai_generated_plan_screen.dart';
import '../../models/ai/models.dart';
import '../../features/user/ai/models/agent_models.dart';
import '../../features/user/events/screens/plan_review_screen.dart';
import '../../features/user/events/screens/my_events_screen.dart';
import '../../features/user/events/screens/event_detail_screen.dart';
import '../../features/user/catalog/screens/vendor_listing_screen.dart';
import '../../features/user/catalog/screens/venue_listing_screen.dart';
import '../../features/user/catalog/screens/vendor_detail_screen.dart';
import '../../features/user/catalog/screens/venue_detail_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/vendor/shell/vendor_shell_screen.dart';
import '../../features/vendor/dashboard/vendor_dashboard_view.dart';
import '../../features/vendor/enquiries/vendor_enquiries_view.dart';
import '../../features/vendor/bookings/vendor_bookings_view.dart';
import '../../features/vendor/profile/vendor_profile_view.dart';
import '../../features/auth/signup_screen.dart';
import '../../services/auth_state_notifier.dart';
import '../../features/user/whatsapp/whatsapp_link_screen.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: authStateNotifier,
  redirect: (context, state) {
    if (authStateNotifier.isLoading) {
      return '/loading';
    }

    final isLoggedIn = authStateNotifier.isAuthenticated;
    final role = authStateNotifier.role;
    final isGoingToLoginOrSignup = state.matchedLocation == '/' || state.matchedLocation == '/signup';

    // 1. Unauthenticated users must log in
    if (!isLoggedIn && !isGoingToLoginOrSignup) {
      return '/';
    }

    // 2. Authenticated users logic
    if (isLoggedIn) {
      // If trying to access login/signup while already logged in
      if (isGoingToLoginOrSignup) {
        // Admin lands on /home — they access /admin via Profile
        if (role == 'vendor') return '/vendor';
        return '/home'; // Default for user AND admin
      }

      // Security Guard: Prevent normal users/vendors from accessing admin
      if (state.matchedLocation.startsWith('/admin') && role != 'admin') {
        return '/home';
      }

      // Security Guard: Prevent normal users/admins from accessing vendor
      if (state.matchedLocation.startsWith('/vendor') && role != 'vendor') {
        return '/home';
      }
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/loading',
      builder: (context, state) => const LoadingScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return VendorShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vendor',
              builder: (context, state) => const VendorDashboardView(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vendor/enquiries',
              builder: (context, state) => const VendorEnquiriesView(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vendor/bookings',
              builder: (context, state) => const VendorBookingsView(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vendor/profile',
              builder: (context, state) => const VendorProfileView(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/ai-planner',
      builder: (context, state) => const AIChatScreen(),
    ),
    GoRoute(
      path: '/ai-generated',
      builder: (context, state) {
        final plan = state.extra as AIGeneratedPlan;
        return AIGeneratedPlanScreen(plan: plan);
      },
    ),
    GoRoute(
      path: '/plan-review',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return PlanReviewScreen(
          conversationId: extra['conversationId'] as String,
          state: extra['state'] as AgentWorkflowState,
        );
      },
    ),
    GoRoute(
      path: '/my-events',
      builder: (context, state) => const MyEventsScreen(),
    ),
    GoRoute(
      path: '/my-events/:id',
      builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/link-whatsapp',
      builder: (context, state) => const WhatsAppLinkScreen(),
    ),
    GoRoute(
      path: '/venues',
      builder: (context, state) => const VenueListingScreen(),
    ),
    GoRoute(
      path: '/venues/:id',
      builder: (context, state) => VenueDetailScreen(venueId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/vendors',
      builder: (context, state) {
        final categoryId = state.uri.queryParameters['categoryId'];
        return VendorListingScreen(categoryId: categoryId);
      },
    ),
    GoRoute(
      path: '/vendors/:id',
      builder: (context, state) => VendorDetailScreen(vendorId: state.pathParameters['id']!),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return UserShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const UserHomeView(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/vendors_tab', // Remapped to Browse / Vendors
              builder: (context, state) => const VendorListingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/planner',
              builder: (context, state) => const UserPlannerView(),
              routes: [
                GoRoute(
                  path: 'details/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return EventPlannerScreen(eventTypeId: id);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const UserProfileView(),
            ),
          ],
        ),
      ],
    ),
  ],
);
