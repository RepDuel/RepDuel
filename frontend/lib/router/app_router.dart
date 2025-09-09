// frontend/lib/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/features/leaderboard/screens/energy_leaderboard_screen.dart';
import 'package:repduel/features/routines/screens/add_exercise_screen.dart';
import 'package:repduel/features/routines/screens/exercise_play_screen.dart';
import 'package:repduel/features/scenario/screens/scenario_screen.dart';
import 'package:repduel/features/routines/screens/summary_screen.dart';

import '../core/models/routine.dart';
import '../core/models/routine_details.dart';
import '../core/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/leaderboard/screens/leaderboard_screen.dart';
import '../features/normal/screens/normal_screen.dart';
import '../features/premium/screens/payment_cancel_screen.dart';
import '../features/premium/screens/payment_success_screen.dart';
import '../features/premium/screens/subscription_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/profile/screens/theme_selector_screen.dart';
import '../features/ranked/screens/ranked_screen.dart';
import '../features/ranked/screens/result_screen.dart';
import '../features/routines/screens/custom_routine_screen.dart';
import '../features/routines/screens/exercise_list_screen.dart';
import '../features/routines/screens/routines_screen.dart';
import '../features/routines/screens/routine_play_screen.dart'; // ✅ NEW import
import '../presentation/scaffolds/main_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authStateStream = ref.watch(authProvider.notifier).authStateStream;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/routines',
    refreshListenable: GoRouterRefreshStream(authStateStream),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/normal',
                name: 'normal',
                builder: (context, state) => const NormalScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/ranked',
                name: 'ranked',
                builder: (context, state) => const RankedScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/routines',
                name: 'routines',
                builder: (context, state) => const RoutinesScreen(),
                routes: [
                  // ✅ New play route for Option A (pass Routine via `extra`)
                  GoRoute(
                    path: 'play',
                    name: 'routinePlay',
                    builder: (context, state) =>
                        RoutinePlayScreen(routine: state.extra as Routine),
                  ),
                  GoRoute(
                      path: 'custom',
                      name: 'createRoutine',
                      builder: (context, state) => const CustomRoutineScreen()),
                  GoRoute(
                      path: 'edit',
                      name: 'editRoutine',
                      builder: (context, state) => CustomRoutineScreen.edit(
                          initial: state.extra! as Routine)),
                  GoRoute(
                      path: 'exercise-list/:routineId',
                      name: 'exerciseList',
                      builder: (context, state) => ExerciseListScreen(
                          routineId: state.pathParameters['routineId']!)),
                ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                      path: 'settings',
                      name: 'settings',
                      builder: (context, state) => const SettingsScreen()),
                  GoRoute(
                      path: 'theme-selector',
                      name: 'themeSelector',
                      builder: (context, state) => const ThemeSelectorScreen()),
                ]),
          ]),
        ],
      ),
      GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/subscribe',
        name: 'subscribe',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
          path: '/payment-success',
          name: 'paymentSuccess',
          builder: (context, state) => const PaymentSuccessScreen()),
      GoRoute(
          path: '/payment-cancel',
          name: 'paymentCancel',
          builder: (context, state) => const PaymentCancelScreen()),
      GoRoute(
        path: '/leaderboard/:scenarioId',
        name: 'liftLeaderboard',
        builder: (context, state) {
          final scenarioId = state.pathParameters['scenarioId']!;
          final liftName = state.uri.queryParameters['liftName'] ?? 'Unknown';
          return LeaderboardScreen(scenarioId: scenarioId, liftName: liftName);
        },
      ),
      GoRoute(
          path: '/add-exercise',
          name: 'addExercise',
          builder: (context, state) => const AddExerciseScreen()),
      GoRoute(
        path: '/summary',
        name: 'summary',
        builder: (context, state) =>
            SummaryScreen(totalVolume: state.extra as int? ?? 0),
      ),
      GoRoute(
        path: '/leaderboard-energy',
        name: 'energyLeaderboard',
        builder: (context, state) => const EnergyLeaderboardScreen(),
      ),
      GoRoute(
        path: '/scenario/:scenarioId',
        name: 'scenario',
        builder: (context, state) {
          final scenarioId = state.pathParameters['scenarioId']!;
          final liftName = state.extra as String? ?? 'Ranked Lift';
          return ScenarioScreen(scenarioId: scenarioId, liftName: liftName);
        },
      ),
      GoRoute(
        path: '/exercise-play',
        name: 'exercise-play',
        builder: (context, state) {
          final exercise = state.extra as Scenario;
          return ExercisePlayScreen(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              sets: exercise.sets,
              reps: exercise.reps);
        },
      ),
      GoRoute(
        path: '/results',
        name: 'results',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final finalScore = extra['finalScore'] as double? ?? 0.0;
          final previousBest = extra['previousBest'] as int? ?? 0;
          final scenarioId = extra['scenarioId'] as String? ?? '';

          if (scenarioId.isEmpty) {
            return const Scaffold(
                body: Center(child: Text("Error: Missing Scenario ID")));
          }

          return ResultScreen(
            finalScore: finalScore,
            previousBest: previousBest,
            scenarioId: scenarioId,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final authStateAsync = ref.read(authProvider);
      if (authStateAsync.isLoading) return null;
      final isLoggedIn = authStateAsync.valueOrNull?.user != null;
      final publicRoutes = ['/login', '/register'];
      final isAuthRoute = publicRoutes.contains(state.uri.path);
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/profile';
      return null;
    },
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    stream.asBroadcastStream().listen((_) => notifyListeners());
  }
}
