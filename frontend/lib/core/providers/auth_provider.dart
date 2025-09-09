// frontend/lib/core/providers/auth_provider.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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
    // Prevent re-running if user is already loaded.
    if (state.token != null) return;

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

  // --- START: MODIFIED METHOD TO FIX RACE CONDITION ---
  Future<void> refreshUserData() async {
    var token = state.token;

    // If the token is null, it means the app is likely still initializing.
    // We explicitly await the initial token load to resolve the race condition.
    if (token == null) {
      debugPrint('[Auth] Token not yet in state, awaiting initial load...');
      await loadUserFromToken();
      // After awaiting, re-read the token from the now-updated state.
      token = state.token;
    }

    // Now we can safely proceed. If token is still null here, the user isn't logged in.
    if (token == null) {
      debugPrint(
          '[Auth] No token found after initial load, cannot refresh user data.');
      return;
    }

    debugPrint('[Auth] Refreshing user data from server...');
    try {
      final user = await _authApi.getMe(token: token);
      if (user != null) {
        state = state.copyWith(user: user);
        debugPrint(
            '[Auth] User data refreshed. New subscription level: ${user.subscriptionLevel}');
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('[Auth] Failed to refresh user data: $e');
    }
  }
  // --- END: MODIFIED METHOD ---

  Future<bool> updateProfile({
    String? gender,
    double? weight,
    String? subscriptionLevel,
  }) async {
    if (state.token == null) return false;
    try {
      final updatedUser = await _authApi.updateMe(
        token: state.token!,
        gender: gender,
        weight: weight,
        subscriptionLevel: subscriptionLevel,
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
    String? subscriptionLevel,
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
          if (weightMultiplier != null) 'weight_multiplier': weightMultiplier,
          if (subscriptionLevel != null)
            'subscription_level': subscriptionLevel,
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

  Future<bool> updateProfilePicture(File imageFile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = state.token;
      if (token == null) throw Exception("No auth token found.");

      final updatedUser =
          await _authApi.uploadProfilePicture(token: token, file: imageFile);

      if (updatedUser != null) {
        state = state.copyWith(user: updatedUser, isLoading: false);
        return true;
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Failed to upload profile picture');
        return false;
      }
    } catch (e) {
      debugPrint('[❌] Profile picture upload error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateProfilePictureFromBytes(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    try {
      final token = state.token;
      if (token == null) return false;

      final updatedUser = await _authApi.uploadProfilePictureFromBytes(
        token: token,
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );

      if (updatedUser != null) {
        state = state.copyWith(user: updatedUser);
        return true;
      }
    } catch (e) {
      debugPrint('[❌] Exception during upload: $e');
    }
    return false;
  }
}
