// frontend/lib/core/providers/navigation_provider.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/navigation_state_persistence.dart';

/// Controls visibility of the main bottom navigation bar.
final bottomNavVisibilityProvider = StateProvider<bool>((ref) => true);

/// Number of branches managed by the [StatefulNavigationShell].
const int navigationBranchCount = 3;

/// Index of the routines tab which doubles as the safe default route.
const int navigationDefaultBranchIndex = 1;

/// Provides access to the persistence layer for navigation state.
///
/// The real implementation is supplied from `main.dart` so tests can inject
/// in-memory stores.
final navigationPersistenceProvider = Provider<NavigationStatePersistence>((ref) {
  throw UnimplementedError('navigationPersistenceProvider must be overridden');
});

/// Supplies the launch-time navigation state restored from persistence.
final navigationLaunchStateProvider = Provider<NavigationLaunchState>((ref) {
  throw UnimplementedError('navigationLaunchStateProvider must be overridden');
});

/// Tracks the active user's identifier for navigation persistence.
final navigationUserIdProvider = StateProvider<String?>((ref) {
  final launchState = ref.watch(navigationLaunchStateProvider);
  return launchState.lastUserId;
});

/// Holds the most recently selected branch index for the navigation shell.
final navigationBranchIndexProvider = StateProvider<int>((ref) {
  final launchState = ref.watch(navigationLaunchStateProvider);
  return launchState.initialIndex;
});

/// Keeps the persisted navigation state aligned with authentication changes.
final navigationAuthSyncProvider = Provider<void>((ref) {
  final persistence = ref.watch(navigationPersistenceProvider);

  String? extractUserId(AsyncValue<AuthState> value) =>
      value.valueOrNull?.user?.id;

  ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
    if (next.isLoading) {
      return;
    }

    final prevUserId = previous == null ? null : extractUserId(previous);
    final nextUserId = extractUserId(next);

    if (prevUserId == nextUserId && nextUserId != null) {
      return;
    }

    final restoredIndex =
        persistence.readBranchIndexForUser(nextUserId) ??
            navigationDefaultBranchIndex;

    ref.read(navigationUserIdProvider.notifier).state = nextUserId;
    ref.read(navigationBranchIndexProvider.notifier).state = restoredIndex;

    // Update persisted last user id asynchronously to avoid awaiting inside
    // the provider listener.
    unawaited(persistence.setLastUserId(nextUserId));
  });
});
