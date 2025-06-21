import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_api_service.dart';
import '../models/user.dart';
import 'api_providers.dart';
import '../services/secure_storage_service.dart';

final authStateProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  final authApi = ref.read(authApiProvider);
  final secureStorage = ref.read(secureStorageProvider);
  return AuthNotifier(authApi, secureStorage);
});

class AuthNotifier extends StateNotifier<User?> {
  final AuthApiService _authApi;
  final SecureStorageService _secureStorage;

  AuthNotifier(this._authApi, this._secureStorage) : super(null);

  Future<bool> login(String email, String password) async {
    final token = await _authApi.login(email, password);
    if (token != null && token.isNotEmpty) {
      await _secureStorage.writeToken(token);
      final user = await _authApi.getMe();
      if (user != null) {
        state = user;
        return true;
      }
    }
    return false;
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
    state = null;
  }

  Future<void> loadUserFromToken() async {
    final token = await _secureStorage.readToken();
    if (token != null && token.isNotEmpty) {
      final user = await _authApi.getMe();
      if (user != null) {
        state = user;
      }
    }
  }
}
