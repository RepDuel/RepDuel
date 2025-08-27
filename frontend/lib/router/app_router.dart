// frontend/lib/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/routine.dart';
import '../core/providers/auth_provider.dart'; // We need the provider itself
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
import '../features/routines/screens/custom_routine_screen.dart';
import '../features/routines/screens/exercise_list_screen.dart';
import '../features/routines/screens/routine_play_screen.dart';
import '../features/routines/screens/routines_screen.dart';
import '../presentation/scaffolds/main_scaffold.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Listen to the auth provider's stream for automatic refresh.
  // authStateStream emits AuthState, which is what GoRouterRefreshStream expects.
  final authStateStream = ref.read(authProvider.notifier).authStateStream; 

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/profile', // Or '/login' if you want to force login check first
    
    // This tells GoRouter to re-evaluate its routes and redirects whenever
    // the authentication state changes.
    refreshListenable: GoRouterRefreshStream(authStateStream), 

    routes: [
      // --- Authenticated Shell Routes ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // The MainScaffold will likely also need to react to auth state,
          // but for the shell itself, it just needs to render the children.
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch( // Branch for '/normal'
            routes: [
              GoRoute(
                path: '/normal',
                name: 'normal',
                builder: (context, state) => const NormalScreen(),
              ),
            ],
          ),
          StatefulShellBranch( // Branch for '/ranked'
            routes: [
              GoRoute(
                path: '/ranked',
                name: 'ranked',
                builder: (context, state) => const RankedScreen(),
              ),
            ],
          ),
          StatefulShellBranch( // Branch for '/routines'
            routes: [
              GoRoute(
                  path: '/routines',
                  name: 'routines',
                  builder: (context, state) => const RoutinesScreen(),
                  routes: [
                    GoRoute(
                      path: 'custom',
                      name: 'createRoutine',
                      builder: (context, state) => const CustomRoutineScreen(),
                    ),
                    GoRoute(
                      path: 'edit',
                      name: 'editRoutine',
                      builder: (context, state) {
                        // Assuming Routine is non-nullable when passed as extra
                        final routine = state.extra! as Routine; 
                        return CustomRoutineScreen.edit(initial: routine);
                      },
                    ),
                    GoRoute(
                      path: 'play',
                      name: 'playRoutine',
                      builder: (context, state) {
                        // Assuming Routine is non-nullable when passed as extra
                        final routine = state.extra! as Routine; 
                        return RoutinePlayScreen(routine: routine);
                      },
                    ),
                    GoRoute(
                      path: 'exercise-list/:routineId',
                      name: 'exerciseList',
                      builder: (context, state) {
                        final routineId = state.pathParameters['routineId']!;
                        return ExerciseListScreen(routineId: routineId);
                      },
                    ),
                  ]),
            ],
          ),
          StatefulShellBranch( // Branch for '/profile'
            routes: [
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
                  ]),
            ],
          ),
        ],
      ),
      // --- Unauthenticated Routes ---
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
      // --- Subscription/Payment Routes ---
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
      // --- Leaderboard Route ---
      GoRoute(
        path: '/leaderboard/:scenarioId',
        name: 'liftLeaderboard',
        builder: (context, state) {
          final scenarioId = state.pathParameters['scenarioId']!;
          final liftName = state.uri.queryParameters['liftName'] ?? 'Unknown';
          return LeaderboardScreen(scenarioId: scenarioId, liftName: liftName);
        },
      ),
    ],
    // --- Redirect Logic ---
    redirect: (context, state) {
      // Access the current authentication state asynchronously using .watch()
      // If the state is loading or errored, we ideally want to wait or show a specific UI.
      // For redirect logic, we often want to check the 'data' state.
      final authStateAsyncValue = ref.watch(authProvider);

      // Check if the authentication state is still loading or has an error.
      // If so, we should not redirect yet, allowing the UI to show loading/error.
      // The `refreshListenable` will trigger this redirect again when auth state settles.
      if (authStateAsyncValue.isLoading || authStateAsyncValue.hasError) {
        return null; // Let the UI handle loading/error states
      }

      // If auth state is loaded successfully, extract the AuthState data.
      final authState = authStateAsyncValue.value; 
      final isLoggedIn = authState?.user != null && authState?.token != null;
      final path = state.uri.path;
      final isAuthRoute = (path == '/login' || path == '/register');

      // --- Redirect Rules ---
      if (!isLoggedIn && !isAuthRoute) {
        // User is logged out and trying to access a non-auth route.
        debugPrint("Redirecting to /login: User logged out, path is $path");
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        // User is logged in and trying to access auth routes.
        debugPrint("Redirecting to /profile: User logged in, path is $path");
        return '/profile'; // Redirect to profile or home page
      }
      
      // If none of the above conditions are met, no redirect is needed.
      return null; 
    },
  );
});

// Helper class to bridge a Stream to a Listenable for GoRouter.
// This ensures GoRouter rebuilds/re-evaluates redirects when auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  // Use a Stream<AuthState> from the AuthNotifier
  GoRouterRefreshStream(Stream<AuthState> stream) {
    // We need to notify listeners immediately upon subscription, in case the stream
    // is already emitting a value or is empty.
    notifyListeners(); 
    
    // Listen to the stream and call notifyListeners() whenever a new AuthState is emitted.
    // .asBroadcastStream() is important if multiple listeners might subscribe.
    stream.asBroadcastStream().listen((_) => notifyListeners());
  }
}