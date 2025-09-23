// frontend/lib/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:repduel/features/leaderboard/screens/energy_leaderboard_screen.dart';
import 'package:repduel/features/routines/models/summary_screen_args.dart';
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
import '../features/profile/screens/public_profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/profile/screens/theme_selector_screen.dart';
import '../features/onboarding/screens/onboarding_profile_screen.dart';
import '../features/ranked/screens/ranked_screen.dart';
import '../features/ranked/screens/result_screen.dart';
import '../features/routines/screens/custom_routine_screen.dart';
import '../features/routines/screens/exercise_list_screen.dart';
import '../features/routines/screens/free_workout_intro_screen.dart';
import '../features/routines/screens/routines_screen.dart';
import '../features/routines/screens/routine_play_screen.dart'; // Option A route
import '../features/routines/screens/routine_import_screen.dart';
import '../presentation/scaffolds/main_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authStateStream = ref.watch(authProvider.notifier).authStateStream;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/routines',
    refreshListenable: GoRouterRefreshStream(authStateStream),
    routes: [
      // ----------------------------------------------------------------------
      // Bottom-tab shell
      // ----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Normal tab
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/normal',
              name: 'normal',
              builder: (context, state) => const NormalScreen(),
            ),
          ]),
          // Ranked tab
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/ranked',
              name: 'ranked',
              builder: (context, state) => const RankedScreen(),
            ),
          ]),
          // Routines tab
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/routines',
              name: 'routines',
              builder: (context, state) => const RoutinesScreen(),
              routes: [
                // ----------------- Option A: Play a Routine via `extra` -----------------
                // This route expects a `Routine` in state.extra but now safely guards it.
                GoRoute(
                  path: 'play',
                  name: 'routinePlay',
                  builder: (context, state) {
                    final extra = state.extra;
                    if (extra is Routine) {
                      return RoutinePlayScreen(routine: extra);
                    }
                    final routineId = state.uri.queryParameters['routineId'];
                    if (routineId != null && routineId.isNotEmpty) {
                      return RoutineImportScreen(routineId: routineId);
                    }
                    return const Scaffold(
                      backgroundColor: Colors.black,
                      body: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Missing routine data. Please open from the Routines tab.',
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Create & Edit custom routine
                GoRoute(
                  path: 'custom',
                  name: 'createRoutine',
                  builder: (context, state) => const CustomRoutineScreen(),
                ),
                GoRoute(
                  path: 'edit',
                  name: 'editRoutine',
                  builder: (context, state) => CustomRoutineScreen.edit(
                      initial: state.extra! as Routine),
                ),

                // ----------------- Option B: Play by routineId param -----------------
                GoRoute(
                  path: 'free-workout',
                  name: 'freeWorkout',
                  builder: (context, state) => const FreeWorkoutIntroScreen(),
                ),
                GoRoute(
                  path: 'free-workout/session',
                  name: 'freeWorkoutSession',
                  builder: (context, state) => const ExerciseListScreen(),
                ),
                GoRoute(
                  path: 'exercise-list/:routineId',
                  name: 'exerciseList',
                  builder: (context, state) => ExerciseListScreen(
                    routineId: state.pathParameters['routineId'],
                  ),
                ),
              ],
            ),
          ]),
          // Profile tab
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'settings',
                  name: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
                GoRoute(
                  path: 'theme-selector',
                  name: 'themeSelector',
                  builder: (context, state) => const ThemeSelectorScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),

      // ----------------------------------------------------------------------
      // Standalone routes (outside shell)
      // ----------------------------------------------------------------------
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding/profile',
        name: 'onboardingProfile',
        builder: (context, state) => const OnboardingProfileScreen(),
      ),
      GoRoute(
        path: '/subscribe',
        name: 'subscribe',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/payment-success',
        name: 'paymentSuccess',
        builder: (context, state) => const PaymentSuccessScreen(),
      ),
      GoRoute(
        path: '/payment-cancel',
        name: 'paymentCancel',
        builder: (context, state) => const PaymentCancelScreen(),
      ),
      GoRoute(
        path: '/profile/:username',
        name: 'publicProfile',
        builder: (context, state) {
          final username = state.pathParameters['username']!;
          return PublicProfileScreen(username: username);
        },
      ),

      // Leaderboards
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
        path: '/leaderboard-energy',
        name: 'energyLeaderboard',
        builder: (context, state) => const EnergyLeaderboardScreen(),
      ),

      // Add exercise
      GoRoute(
        path: '/add-exercise',
        name: 'addExercise',
        builder: (context, state) => const AddExerciseScreen(),
      ),

      // Summary screen (prefers SummaryScreenArgs; num fallback for legacy callers)
      GoRoute(
        path: '/summary',
        name: 'summary',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is SummaryScreenArgs) {
            return SummaryScreen(
              totalVolumeKg: extra.totalVolumeKg,
              personalBests: extra.personalBests,
            );
          }
          final fallbackVolume =
              extra is num ? extra.toDouble() : 0.0;
          return SummaryScreen(totalVolumeKg: fallbackVolume);
        },
      ),

      // Scenario screen (Ranked flow)
      GoRoute(
        path: '/scenario/:scenarioId',
        name: 'scenario',
        builder: (context, state) {
          final scenarioId = state.pathParameters['scenarioId']!;
          final liftName = state.extra as String? ?? 'Ranked Lift';
          return ScenarioScreen(scenarioId: scenarioId, liftName: liftName);
        },
      ),

      // Exercise play (Workout flow) — expects a Scenario in `extra`, now guarded.
      GoRoute(
        path: '/exercise-play',
        name: 'exercise-play',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Scenario) {
            return ExercisePlayScreen(
              exerciseId: extra.id,
              exerciseName: extra.name,
              sets: extra.sets,
              reps: extra.reps,
            );
          }
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Missing exercise data. Please open from the routine screen.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),

      // Results screen for Ranked flow
      GoRoute(
        path: '/results',
        name: 'results',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          final finalScore = (extra['finalScore'] as num?)?.toDouble() ?? 0.0;
          final previousBest =
              (extra['previousBest'] as num?)?.toDouble() ?? 0.0;
          final scenarioId = extra['scenarioId'] as String? ?? '';

          if (scenarioId.isEmpty) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  "Error: Missing Scenario ID",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          return ResultScreen(
            finalScore: finalScore,
            previousBest: previousBest,
            scenarioId: scenarioId,
          );
        },
      ),
    ],

    // ----------------------------------------------------------------------
    // Global redirect (auth)
    // ----------------------------------------------------------------------
    redirect: (context, state) {
      final authStateAsync = ref.read(authProvider);
      if (authStateAsync.isLoading) return null;

      final isLoggedIn = authStateAsync.valueOrNull?.user != null;
      final publicRoutes = ['/login', '/register'];
      final isAuthRoute = publicRoutes.contains(state.uri.path);
      final fromParam = state.uri.queryParameters['from'];

      // If not logged in and trying to access a private route, redirect to login
      // and preserve the intended destination as ?from=...
      if (!isLoggedIn && !isAuthRoute) {
        final dest = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$dest';
      }

      // If logged in and currently on an auth route, send them to the original
      // requested location if provided, otherwise default to profile
      if (isLoggedIn && isAuthRoute) {
        if (fromParam != null && fromParam.isNotEmpty) {
          return fromParam;
        }
        return '/profile';
      }
      return null;
    },
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    // Trigger initial build
    notifyListeners();
    // Notify router whenever auth state changes
    stream.asBroadcastStream().listen((_) => notifyListeners());
  }
}
