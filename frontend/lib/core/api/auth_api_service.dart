import 'dart:convert';

import '../models/user.dart';
import '../services/secure_storage_service.dart';
import 'api_client.dart';

class AuthApiService {
  final ApiClient _client;

  AuthApiService(this._client);

  Future<User?> register(String username, String email, String password) async {
    final response = await _client.post(
      '/users/',
      {
        'username': username,
        'email': email,
        'password': password,
      },
      auth: false,
    );

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return User.fromJson(json);
    }

    return null;
  }

  Future<bool> login(String email, String password, SecureStorageService secureStorage) async {
    final response = await _client.post(
      '/users/login',
      {
        'email': email,
        'password': password,
      },
      auth: false,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final token = json['access_token'];
      await secureStorage.writeToken(token);
      return true;
    }

    return false;
  }

  Future<User?> getCurrentUser() async {
    final response = await _client.get('/users/me');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return User.fromJson(json);
    }

    return null;
  }
}
