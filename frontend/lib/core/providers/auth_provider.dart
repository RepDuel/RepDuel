// frontend/lib/core/providers/auth_provider.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/auth_api_service.dart';
import '../models/user.dart';
import '../services/secure_storage_service.dart';
import 'api_providers.dart';

class AuthState {
  final User? user;
  final String? token;

  AuthState({this.user, this.token});

  AuthState copyWith({User? user, String? token}) {
    return AuthState(user: user ?? this.user, token: token ?? this.token);
  }

  factory AuthState.initial() => AuthState(user: null, token: null);
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>((ref) {
  final publicClient = ref.read(publicHttpClientProvider);
  final privateClient = ref.read(privateHttpClientProvider);
  final authApi =
      AuthApiService(publicClient: publicClient, privateClient: privateClient);
  final secureStorage = ref.read(secureStorageProvider);
  return AuthNotifier(authApi, secureStorage);
});

class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final AuthApiService _authApi;
  final SecureStorageService _secureStorage;
  final StreamController<AuthState> _authStateChangeController =
      StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateStream => _authStateChangeController.stream;

  AuthNotifier(this._authApi, this._secureStorage)
      : super(const AsyncValue.loading()) {
    _initAuth();
  }

  @override
  set state(AsyncValue<AuthState> newState) {
    super.state = newState;
    newState.whenOrNull(
      data: (authStateData) => _authStateChangeController.add(authStateData),
    );
  }

  Future<void> _initAuth() async {
    try {
      await loadUserFromToken();
    } catch (e) {
      state = AsyncValue.error("Initialization failed: $e", StackTrace.current);
      debugPrint("[AuthNotifier] Initialization failed: $e");
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final tokenResponse = await _authApi.login(email, password);
      if (tokenResponse != null && tokenResponse.accessToken.isNotEmpty) {
        await _secureStorage.writeToken(tokenResponse.accessToken);
        final user = await _authApi.getMe(token: tokenResponse.accessToken);
        if (user != null) {
          state = AsyncValue.data(
              AuthState(user: user, token: tokenResponse.accessToken));
        } else {
          await _secureStorage.deleteToken();
          state = AsyncValue.error(
              'Login successful but user data not found.', StackTrace.current);
        }
      } else {
        await _secureStorage.deleteToken();
        state = AsyncValue.error(
            'Login failed. Invalid credentials.', StackTrace.current);
      }
    } catch (e) {
      await _secureStorage.deleteToken();
      String errorMessage = 'An unexpected error occurred.';
      if (e.toString().contains('401')) {
        errorMessage = 'Incorrect email or password.';
      } else {
        errorMessage = 'Login error: $e';
      }
      state = AsyncValue.error(errorMessage, StackTrace.current);
      debugPrint("[AuthNotifier] Login error: $e");
    }
  }

  Future<void> register(String username, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final newUser = await _authApi.register(username, email, password);
      if (newUser != null) {
        state = AsyncValue.data(AuthState.initial());
        debugPrint("[AuthNotifier] Registration successful for $username.");
      } else {
        state = AsyncValue.error(
            'Registration failed. Please try again.', StackTrace.current);
      }
    } catch (e) {
      state =
          AsyncValue.error('Error during registration: $e', StackTrace.current);
      debugPrint("[AuthNotifier] Registration error: $e");
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
    state = AsyncValue.data(AuthState.initial());
  }

  Future<void> loadUserFromToken() async {
    final tokenString = await _secureStorage.readToken();
    if (tokenString == null || tokenString.isEmpty) {
      state = AsyncValue.data(AuthState.initial());
      return;
    }

    try {
      final user = await _authApi.getMe(token: tokenString);
      if (user != null) {
        state = AsyncValue.data(AuthState(user: user, token: tokenString));
      } else {
        await _secureStorage.deleteToken();
        state = AsyncValue.data(AuthState.initial());
      }
    } catch (e) {
      await _secureStorage.deleteToken();
      state = AsyncValue.error(
          'Session expired. Please log in again. ($e)', StackTrace.current);
      debugPrint("[AuthNotifier] Load user from token error: $e");
    }
  }

  Future<void> refreshUserData() async {
    final currentStateData = state.valueOrNull;
    final token = currentStateData?.token;
    if (token == null) {
      await loadUserFromToken();
      return;
    }
    try {
      final user = await _authApi.getMe(token: token);
      if (user != null) {
        state = AsyncValue.data(currentStateData!.copyWith(user: user));
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint("[AuthNotifier] Refresh user data error: $e");
      await logout();
    }
  }

  Future<bool> updateUser({
    String? gender,
    double? weight,
    double? weightMultiplier,
    String? subscriptionLevel,
  }) async {
    final currentStateData = state.valueOrNull;
    final token = currentStateData?.token;
    if (token == null) return false;

    try {
      final updates = <String, dynamic>{};
      if (gender != null) updates['gender'] = gender;
      if (weight != null) updates['weight'] = weight;
      if (weightMultiplier != null) {
        updates['weight_multiplier'] = weightMultiplier;
      }
      if (subscriptionLevel != null) {
        updates['subscription_level'] = subscriptionLevel;
      }

      if (updates.isEmpty) return true;

      final updatedUser =
          await _authApi.updateUser(token: token, updates: updates);
      if (updatedUser != null) {
        state = AsyncValue.data(currentStateData!.copyWith(user: updatedUser));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("[AuthNotifier] Error updating user: $e");
      return false;
    }
  }

  Future<bool> updateProfilePictureFromBytes(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    final currentStateData = state.valueOrNull;
    final token = currentStateData?.token;
    if (token == null) return false;

    try {
      final updatedUser = await _authApi.uploadProfilePictureFromBytes(
        token: token,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
      if (updatedUser != null) {
        state = AsyncValue.data(currentStateData!.copyWith(user: updatedUser));
        return true;
      }
    } catch (e) {
      debugPrint(
          "[AuthNotifier ❌] Exception during profile picture upload: $e");
    }
    return false;
  }

  void updateLocalUserEnergy(
      {required double newEnergy, required String newRank}) {
    final currentState = state.valueOrNull;
    final currentUser = currentState?.user;

    if (currentUser == null) {
      return;
    }

    final updatedUser = currentUser.copyWith(
      energy: newEnergy,
      rank: newRank,
    );

    state = AsyncValue.data(currentState!.copyWith(user: updatedUser));
  }

  @override
  void dispose() {
    _authStateChangeController.close();
    super.dispose();
  }
}
