import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/user/shell/user_shell_screen.dart';
import '../../features/user/home/user_home_view.dart';
import '../../features/user/planner/user_planner_view.dart';
import '../../features/user/planner/event_planner_screen.dart';
import '../../features/user/categories/user_categories_view.dart';
import '../../features/user/categories/category_listing_screen.dart';
import '../../features/user/profile/user_profile_view.dart';
import '../../features/user/ai/screens/ai_chat_screen.dart';
import '../../features/user/ai/screens/ai_generated_plan_screen.dart';
import '../../models/ai/models.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/vendor/vendor_dashboard_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../services/auth_state_notifier.dart';

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
        if (role == 'admin') return '/admin';
        if (role == 'vendor') return '/vendor';
        return '/home'; // Default user
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
    GoRoute(
      path: '/vendor',
      builder: (context, state) => const VendorDashboardScreen(),
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
              path: '/categories',
              builder: (context, state) => const UserCategoriesView(),
              routes: [
                GoRoute(
                  path: 'listing/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return CategoryListingScreen(categoryId: id);
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
