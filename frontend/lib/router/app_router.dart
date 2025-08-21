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
import '../features/premium/screens/subscription_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/routines/screens/add_exercise_screen.dart';
import '../features/routines/screens/custom_routine_screen.dart';
import '../features/routines/screens/exercise_list_screen.dart';

// --- NEW SHELL IMPORT ---
// This is the new parent widget for the main screens. We will create this file next.
import '../presentation/scaffolds/main_scaffold.dart';


final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    // The initial location now points to the shell route, starting at the profile tab (index 3).
    initialLocation: '/shell/3',
    routes: [
      // NEW SHELL ROUTE: This single route replaces the old /normal, /ranked, etc.
      // It builds the main scaffold which contains the bottom nav bar and hosts the pages.
      GoRoute(
        path: '/shell/:index',
        builder: (context, state) {
          // Safely parse the index from the URL, defaulting to 0.
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
        path: '/subscribe',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/payment-success',
        builder: (context, state) => const PaymentSuccessScreen(),
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
      
      // We check if the path starts with /shell because it now has a parameter.
      final isAppRoute = path.startsWith('/shell');
      final isPublicRoute = path == '/login' || path == '/register' || path == '/payment-success';
      
      // If user is not logged in and tries to access a protected app route, redirect to login.
      if (!isLoggedIn && !isPublicRoute && isAppRoute) {
        return '/login';
      }

      // If user is logged in and is on the login page, redirect them into the app.
      if (isLoggedIn && (path == '/login' || path == '/register')) {
        // UPDATED REDIRECT: Go to the shell, starting at the profile tab (index 3).
        return '/shell/3';
      }

      return null;
    },
  );
});