// frontend/lib/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// --- Core and Feature Imports ---
import '../core/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/premium/screens/payment_success_screen.dart';
import '../features/premium/screens/payment_cancel_screen.dart';
import '../features/premium/screens/subscription_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/profile/screens/theme_selector_screen.dart';
import '../features/routines/screens/add_exercise_screen.dart';
import '../features/routines/screens/custom_routine_screen.dart';
import '../features/routines/screens/exercise_list_screen.dart';
import '../presentation/scaffolds/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/shell/3',
    routes: [
      GoRoute(
        path: '/shell/:index',
        builder: (context, state) {
          final indexString = state.pathParameters['index'] ?? '0';
          final index = int.tryParse(indexString) ?? 0;
          return MainScaffold(initialIndex: index);
        },
      ),
      GoRoute(
        path: '/routines/custom',
        builder: (context, state) => const CustomRoutineScreen(),
      ),
      GoRoute(
        path: '/routines/add-exercise',
        builder: (context, state) => const AddExerciseScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/theme-selector',
        builder: (context, state) => const ThemeSelectorScreen(),
      ),
      GoRoute(
        path: '/subscribe',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/payment-success',
        builder: (context, state) => const PaymentSuccessScreen(),
      ),
      GoRoute(
        path: '/payment-cancel',
        builder: (context, state) => const PaymentCancelScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/exercise_list/:routineId',
        builder: (context, state) {
          final routineId = state.pathParameters['routineId']!;
          return ExerciseListScreen(routineId: routineId);
        },
      ),
      GoRoute(
        path: '/leaderboard/:scenarioId',
        builder: (context, state) {
          final scenarioId = state.pathParameters['scenarioId']!;
          final liftName = state.uri.queryParameters['liftName'] ?? 'Unknown';
          return LeaderboardScreen(
            scenarioId: scenarioId,
            liftName: liftName,
          );
        },
      ),
    ],

    /// Simple auth guard
    redirect: (context, state) {
      final isLoggedIn = auth.user != null;
      final path = state.uri.path;

      // Extend the public routes to allow access to the theme selector for previewing
      final isAppRoute = path.startsWith('/shell');
      final isPublicRoute = path == '/login' ||
          path == '/register' ||
          path == '/payment-success' ||
          path == '/payment-cancel';

      if (!isLoggedIn && !isPublicRoute && isAppRoute) {
        return '/login';
      }

      if (isLoggedIn && (path == '/login' || path == '/register')) {
        return '/shell/3';
      }

      return null;
    },
  );
});