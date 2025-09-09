// frontend/lib/router/app_router.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/chat/screens/chat_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/normal/screens/normal_screen.dart';
import '../features/premium/screens/payment_success_screen.dart';
import '../features/premium/screens/subscription_screen.dart';
import '../features/profile/screens/profile_wrapper.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/ranked/screens/ranked_screen.dart';
import '../features/routines/screens/add_exercise_screen.dart';
import '../features/routines/screens/custom_routine_screen.dart';
import '../features/routines/screens/exercise_list_screen.dart';
import '../features/routines/screens/routines_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  // The incorrect line has been removed from here.
  // GoRouter will automatically respect the global setting from main.dart.

  return GoRouter(
    initialLocation: '/profile',
    routes: [
      // ... your routes remain unchanged ...
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
        path: '/routines/custom',
        builder: (context, state) => const CustomRoutineScreen(),
      ),
      GoRoute(
        path: '/routines/add-exercise',
        builder: (context, state) => const AddExerciseScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileWrapper(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
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

      final isPublicRoute =
          path == '/login' || path == '/register' || path == '/payment-success';

      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }

      if (isLoggedIn && path == '/login') {
        return '/profile';
      }

      return null;
    },
  );
});
