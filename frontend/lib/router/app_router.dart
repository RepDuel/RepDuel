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
  // Watching the authProvider to ensure we always have the updated state
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/profile', // Default route if no other route matches
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
    redirect: (context, state) {
      // Reading auth provider to get the current user state
      final isLoggedIn = auth.user != null;
      final path = state.uri.path;

      // Check if user is logged in or not
      final isAuthRoute = path == '/login' || path == '/register';

      // If user is not logged in and tries to access protected routes, redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login'; // Redirect to login if not logged in
      }

      // If user is logged in and tries to access login page, redirect to profile
      if (isLoggedIn && path == '/login') {
        return '/profile';
      }

      return null; // No redirection needed
    },
  );
});
