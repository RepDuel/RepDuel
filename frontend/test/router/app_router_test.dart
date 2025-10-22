// frontend/test/router/app_router_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repduel/core/api/auth_api_service.dart';
import 'package:repduel/core/models/user.dart';
import 'package:repduel/core/providers/auth_provider.dart';
import 'package:repduel/core/providers/navigation_provider.dart';
import 'package:repduel/core/services/navigation_state_persistence.dart';
import 'package:repduel/core/services/secure_storage_service.dart';
import 'package:repduel/core/utils/http_client.dart';
import 'package:repduel/router/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('routerProvider navigation persistence', () {
    late SharedPreferences preferences;
    late NavigationStatePersistence persistence;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      persistence = NavigationStatePersistence(
        preferences,
        branchCount: navigationBranchCount,
        defaultIndex: navigationDefaultBranchIndex,
      );
    });

    ProviderContainer createContainer({
      required NavigationLaunchState launchState,
      required AuthState authState,
    }) {
      return ProviderContainer(
        overrides: [
          navigationPersistenceProvider.overrideWithValue(persistence),
          navigationLaunchStateProvider.overrideWithValue(launchState),
          authProvider.overrideWith((ref) {
            final publicClient = HttpClient(Dio());
            final privateClient = HttpClient(Dio());
            final secureStorage = SecureStorageService(
              secureStore: InMemoryKeyValueStore(),
              webFallbackStore: InMemoryKeyValueStore(),
            );
            final authApi = AuthApiService(
              publicClient: publicClient,
              privateClient: privateClient,
            );
            final notifier = AuthNotifier.testing(
              authApi,
              secureStorage,
              privateClient,
            )..state = AsyncValue.data(authState);

            return notifier;
          }),
        ],
      );
    }

    test('restores persisted branch as the initial router location', () async {
      final user = User(
        id: 'user-123',
        username: 'repduel',
        email: 'user@example.com',
        isActive: true,
        createdAt: DateTime.parse('2024-01-01'),
        updatedAt: DateTime.parse('2024-01-01'),
        subscriptionLevel: 'free',
        energy: 0,
        weightMultiplier: 1,
        preferredUnit: 'kg',
      );

      await persistence.persistBranchIndex(2, userId: user.id);
      final launchState = persistence.restoreLaunchState();

      final container = createContainer(
        launchState: launchState,
        authState: AuthState(user: user, token: 'token-abc'),
      );

      final router = container.read(routerProvider);
      final initialLocation =
          router.routeInformationProvider.value.uri.toString();

      expect(initialLocation, '/profile');
      expect(container.read(navigationBranchIndexProvider), 2);

      container.dispose();
    });

    test('falls back to routines when no persisted branch exists', () {
      final launchState = persistence.restoreLaunchState();

      final container = createContainer(
        launchState: launchState,
        authState: AuthState.initial(),
      );

      final router = container.read(routerProvider);
      final initialLocation =
          router.routeInformationProvider.value.uri.toString();

      expect(initialLocation, '/routines');
      expect(container.read(navigationBranchIndexProvider),
          navigationDefaultBranchIndex);

      container.dispose();
    });
  });
}
