import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/ranked/screens/ranked_screen.dart';
import '../features/routines/screens/routines_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/normal/screens/normal_screen.dart';
import '../core/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final isAuthenticated = authState.token != null;

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
        builder: (context, state) => const ProfileScreen(),
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
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // Uncomment and customize for auth handling:
      // if (!isAuthenticated && !isLoggingIn) {
      //   return '/login';
      // }

      // if (isAuthenticated && isLoggingIn) {
      //   return '/home';
      // }

      return null;
    },
  );
});
