// lib/core/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_api_service.dart';
import '../models/user.dart';
import 'api_providers.dart';
import '../services/secure_storage_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authApi = ref.read(authApiProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return AuthNotifier(authApi, secureStorage);
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authApi = ref.read(authApiProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return AuthNotifier(authApi, secureStorage);
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _authApi;
  final SecureStorageService _secureStorage;

  AuthNotifier(this._authApi, this._secureStorage)
      : super(AuthState()) {
    loadUserFromToken();
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await _authApi.login(email, password);
      if (token != null && token.isNotEmpty) {
        await _secureStorage.writeToken(token);
        final user = await _authApi.getMe();
        if (user != null) {
          state = AuthState(user: user, isLoading: false);
          return true;
        }
      }
      state = state.copyWith(isLoading: false, error: 'Invalid credentials');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authApi.register(username, email, password);
      if (user != null) {
        state = AuthState(user: user, isLoading: false);
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
    final token = await _secureStorage.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        final user = await _authApi.getMe();
        if (user != null) {
          state = AuthState(user: user);
        }
      } catch (_) {
        // silently fail
      }
    }
  }
}
