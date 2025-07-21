// frontend/lib/core/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_api_service.dart';
import '../models/user.dart';
import '../services/secure_storage_service.dart';
import 'api_providers.dart';

// Main authentication state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final publicClient = ref.read(publicHttpClientProvider);
  final privateClient = ref.read(privateHttpClientProvider);
  final authApi = AuthApiService(
    publicClient: publicClient,
    privateClient: privateClient,
  );
  final secureStorage = ref.read(secureStorageProvider);
  return AuthNotifier(authApi, secureStorage);
});

final authStateProvider = authProvider;

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _authApi;
  final SecureStorageService _secureStorage;

  AuthNotifier(this._authApi, this._secureStorage) : super(AuthState()) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    await loadUserFromToken();
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tokenResponse = await _authApi.login(email, password);
      if (tokenResponse != null && tokenResponse.accessToken.isNotEmpty) {
        await _secureStorage.writeToken(tokenResponse.accessToken);
        final user = await _authApi.getMe(token: tokenResponse.accessToken);
        if (user != null) {
          state = AuthState(
            user: user,
            token: tokenResponse.accessToken,
            isLoading: false,
          );
          return true;
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed. Invalid credentials.',
      );
      return false;
    } catch (e) {
      final errorMessage = e.toString().contains('401')
          ? 'Incorrect email or password.'
          : 'An unexpected error occurred.';
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authApi.register(username, email, password);
      if (user != null) {
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Registration failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
    state = AuthState();
  }

  Future<void> loadUserFromToken() async {
    final tokenString = await _secureStorage.readToken();
    if (tokenString != null && tokenString.isNotEmpty) {
      try {
        final user = await _authApi.getMe(token: tokenString);
        if (user != null) {
          state = AuthState(user: user, token: tokenString);
        } else {
          await _secureStorage.deleteToken();
          state = AuthState();
        }
      } catch (_) {
        await _secureStorage.deleteToken();
        state = AuthState();
      }
    }
  }

  Future<bool> updateProfile({String? gender, double? weight}) async {
    if (state.token == null) return false;
    try {
      final updatedUser = await _authApi.updateMe(
        token: state.token!,
        gender: gender,
        weight: weight,
      );
      if (updatedUser != null) {
        state = state.copyWith(user: updatedUser);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updateUser({
    String? gender,
    double? weight,
    double? weightMultiplier,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = state.token;
      if (token == null) {
        throw Exception("No auth token found.");
      }

      final updatedUser = await _authApi.updateUser(
        token: token,
        updates: {
          if (gender != null) 'gender': gender,
          if (weight != null) 'weight': weight,
          if (weightMultiplier != null)
            'weight_multiplier': weightMultiplier, // Handle weight multiplier
        },
      );

      if (updatedUser != null) {
        state = state.copyWith(user: updatedUser, isLoading: false);
        return true;
      } else {
        state =
            state.copyWith(isLoading: false, error: 'Failed to update user');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
