// frontend/lib/core/providers/auth_provider.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../api/auth_api_service.dart';
import '../models/user.dart';
import '../providers/secure_storage_provider.dart';
import '../services/secure_storage_service.dart';
import '../utils/http_client.dart';
import 'api_providers.dart';

class AuthState {
  final User? user;
  final String? token;
  final String? statusMessage;

  AuthState({this.user, this.token, this.statusMessage});

  AuthState copyWith({
    User? user,
    String? token,
    String? statusMessage,
    bool resetStatusMessage = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      statusMessage: resetStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
    );
  }

  factory AuthState.initial({String? statusMessage}) =>
      AuthState(user: null, token: null, statusMessage: statusMessage);
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>((ref) {
  final publicClient = ref.read(publicHttpClientProvider);
  final privateClient = ref.read(privateHttpClientProvider);
  final authApi =
      AuthApiService(publicClient: publicClient, privateClient: privateClient);
  final secureStorage = ref.read(secureStorageProvider);
  return AuthNotifier(authApi, secureStorage, privateClient);
});

class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final AuthApiService _authApi;
  final SecureStorageService _secureStorage;
  final HttpClient _privateClient;
  final StreamController<AuthState> _authStateChangeController =
      StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateStream => _authStateChangeController.stream;

  AuthNotifier(this._authApi, this._secureStorage, this._privateClient)
      : super(const AsyncValue.loading()) {
    _initAuth();
  }

  @visibleForTesting
  AuthNotifier.testing(
    this._authApi,
    this._secureStorage,
    this._privateClient,
  ) : super(const AsyncValue.loading());

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

  Future<bool> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final tokenResponse = await _authApi.login(email, password);
      if (tokenResponse != null && tokenResponse.accessToken.isNotEmpty) {
        await _secureStorage.writeToken(tokenResponse.accessToken);
        final user = await _authApi.getMe(token: tokenResponse.accessToken);
        if (user != null) {
          state = AsyncValue.data(
              AuthState(user: user, token: tokenResponse.accessToken));
          return true;
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
    return false;
  }

  Future<bool> register(String username, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final newUser = await _authApi.register(username, email, password);
      if (newUser != null) {
        state = AsyncValue.data(AuthState.initial());
        debugPrint("[AuthNotifier] Registration successful for $username.");
        return true;
      } else {
        state = AsyncValue.error(
            'Registration failed. Please try again.', StackTrace.current);
      }
    } catch (error, stackTrace) {
      final friendlyMessage = _describeRegistrationFailure(error);
      if (friendlyMessage != null && friendlyMessage.trim().isNotEmpty) {
        debugPrint('[AuthNotifier] Registration error detail: $friendlyMessage');
        state = AsyncValue.error(friendlyMessage.trim(), stackTrace);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      debugPrint("[AuthNotifier] Registration error: $error");
    }
    return false;
  }

  String? _describeRegistrationFailure(Object error) {
    final extracted = _extractRegistrationErrorMessage(error);
    final candidate = (extracted != null && extracted.trim().isNotEmpty)
        ? extracted.trim()
        : error.toString();

    if (candidate.isEmpty) {
      return null;
    }

    final normalized = candidate.toLowerCase();

    bool mentionsUsername(String value) =>
        value.contains('username') ||
        value.contains('user name') ||
        value.contains('handle');

    bool mentionsEmail(String value) =>
        value.contains('email') || value.contains('e-mail') || value.contains('mail');

    bool impliesTaken(String value) {
      if (!value.contains('already') && !value.contains('duplicate')) {
        return value.contains('unique constraint') ||
            value.contains('unique violation') ||
            value.contains('23505') ||
            value.contains('conflict');
      }

      return value.contains('already taken') ||
          value.contains('already exists') ||
          value.contains('already registered') ||
          value.contains('already in use') ||
          value.contains('already used') ||
          value.contains('already associated') ||
          value.contains('already linked') ||
          value.contains('duplicate');
    }

    if (mentionsUsername(normalized) && impliesTaken(normalized)) {
      return 'That username is already taken. Try a different one.';
    }

    if (mentionsEmail(normalized) && impliesTaken(normalized)) {
      return 'That email is already in use. Try a different email or log in.';
    }

    return (extracted != null && extracted.trim().isNotEmpty)
        ? extracted.trim()
        : candidate;
  }

  String? _extractRegistrationErrorMessage(Object error) {
    if (error is DioException) {
      final response = error.response;
      if (response != null) {
        final message = _parseServerMessage(response.data);
        if (message != null && message.isNotEmpty) {
          return message;
        }
        final statusMessage = response.statusMessage;
        if (statusMessage != null && statusMessage.trim().isNotEmpty) {
          return statusMessage.trim();
        }
      }
      final dioMessage = error.message;
      if (dioMessage != null && dioMessage.trim().isNotEmpty) {
        return dioMessage.trim();
      }
    }

    final raw = error.toString();
    return raw.isNotEmpty ? raw : null;
  }

  String? _parseServerMessage(dynamic data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      if (detail is Map) {
        final msg = detail['msg'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final error = data['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return null;
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
    state = AsyncValue.data(
      AuthState.initial(statusMessage: 'Logged out successfully'),
    );
  }

  void clearStatusMessage() {
    final currentState = state.valueOrNull;
    if (currentState == null) {
      return;
    }
    state = AsyncValue.data(currentState.copyWith(resetStatusMessage: true));
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
    String? preferredUnit,
    String? displayName,
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
      if (preferredUnit != null) {
        updates['preferred_unit'] = preferredUnit;
      }
      if (displayName != null) {
        updates['display_name'] = displayName;
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

  Future<bool> setPreferredUnit(String unit) async {
    final currentStateData = state.valueOrNull;
    final token = currentStateData?.token;
    if (token == null) return false;

    try {
      final res = await _privateClient.patch(
        '/users/me/unit',
        data: {'preferred_unit': unit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final updatedUser = User.fromJson(res.data as Map<String, dynamic>);
      final adjustedUser = updatedUser.copyWith(
        weightMultiplier: unit == 'lbs' ? 2.2046226218 : 1.0,
      );
      state = AsyncValue.data(currentStateData!.copyWith(user: adjustedUser));
      return true;
    } catch (e) {
      debugPrint("[AuthNotifier] Error setting preferred unit: $e");
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

  void updateLocalUserEnergy({
    required double newEnergy,
    required String newRank,
  }) {
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
