// frontend/lib/core/api/auth_api_service.dart

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../models/token.dart';
import '../models/user.dart';
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

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 200 || statusCode == 201) {
      return User.fromJson(response.data);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: response.data,
    );
  }

  Future<User?> getMe({String? token}) async {
    if (token == null || token.isEmpty) {
      return null;
    }

    final options = Options(headers: {'Authorization': 'Bearer $token'});
    final response = await _publicClient.get('/users/me', options: options);

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }

  Future<User?> updateUser({
    required String token,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _privateClient.patch(
      '/users/me',
      data: updates,
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }

  Future<User?> uploadProfilePictureFromBytes({
    required String token,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final formData = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    });

    final response = await _privateClient.dio.patch(
      '/users/me/avatar',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }
}
