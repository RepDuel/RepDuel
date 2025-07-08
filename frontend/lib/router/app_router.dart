import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/ranked/screens/ranked_screen.dart';
import '../features/routines/screens/routines_screen.dart';
import '../features/profile/screens/profile_wrapper.dart';
import '../features/normal/screens/normal_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/routines/screens/exercise_list_screen.dart';
import '../core/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/ranked',
    routes: [
      GoRoute(
        path: '/normal',
        builder: (context, state) => const NormalScreen(),
      ),
      GoRoute(
        path: '/ranked',
        builder: (context, state) => const RankedScreen(),
      ),
      GoRoute(
        path: '/routines',
        builder: (context, state) => const RoutinesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileWrapper(),
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
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      // New Route for Exercise List
      GoRoute(
        path:
            '/exercise_list/:routineId', // Route with dynamic ID for the routine
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
    redirect: (BuildContext context, GoRouterState state) {
      return null;
    },
  );
});
