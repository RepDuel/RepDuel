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
      data: {'username': email, 'password': password},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
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

  Future<User?> getMe({String? token}) async {
    Options? options;
    if (token != null) {
      options = Options(headers: {'Authorization': 'Bearer $token'});
    }

    final response = await _privateClient.get('/users/me', options: options);

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }

  Future<User?> updateUser({
    required String token,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _privateClient.dio.patch(
      '/users/me',
      data: updates,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }

  Future<User?> updateMe({
    required String token,
    String? gender,
    double? weight,
  }) async {
    final data = <String, dynamic>{};
    if (gender != null) data['gender'] = gender;
    if (weight != null) data['weight'] = weight;

    final response = await _privateClient.patch(
      '/users/me',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }
}
