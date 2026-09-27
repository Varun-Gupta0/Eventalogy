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
import '../../features/user/ai/screens/ai_planner_flow_screen.dart';
import '../../features/user/ai/screens/ai_generated_plan_screen.dart';
import '../../models/ai/models.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const PlaceholderScreen(title: 'Admin Panel'),
    ),
    GoRoute(
      path: '/ai-planner',
      builder: (context, state) => const AIPlannerFlowScreen(),
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
