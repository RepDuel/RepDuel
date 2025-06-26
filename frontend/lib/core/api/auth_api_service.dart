import 'package:dio/dio.dart';

import '../models/user.dart';
import '../models/token.dart';
import '../utils/http_client.dart';

class AuthApiService {
  final HttpClient _publicClient;
  final HttpClient _privateClient;

  AuthApiService({
    required HttpClient publicClient,
    required HttpClient privateClient,
  })  : _publicClient = publicClient,
        _privateClient = privateClient;

  Future<Token?> login(String email, String password) async {
    final response = await _publicClient.post(
      '/users/login',
      data: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      return Token.fromJson(response.data);
    }
    return null;
  }

  Future<User?> register(String username, String email, String password) async {
    final response = await _publicClient.post(
      '/users/',
      data: {'username': username, 'email': email, 'password': password},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return User.fromJson(response.data);
    }
    return null;
  }

  // Update getMe to optionally accept a token for direct use
  Future<User?> getMe({String? token}) async {
    Options? options;
    if (token != null) {
      options = Options(headers: {'Authorization': 'Bearer $token'});
    }

    // Always use the private client, but pass options if token is provided directly
    final response = await _privateClient.get('/users/me', options: options);

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }
}