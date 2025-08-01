// frontend/lib/core/api/auth_api_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../models/token.dart';
import '../utils/http_client.dart';
import 'package:http_parser/http_parser.dart';

class AuthApiService {
  final HttpClient _publicClient;
  final HttpClient _privateClient;

  AuthApiService({
    required HttpClient publicClient,
    required HttpClient privateClient,
  })  : _publicClient = publicClient,
        _privateClient = privateClient;

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
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/form-data',
      }),
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }

  Future<User?> uploadAvatar({
    required String token,
    required MultipartFile file,
  }) async {
    final formData = FormData.fromMap({
      'avatar': file,
    });

    final response = await _privateClient.dio.patch(
      '/users/me/avatar',
      data: formData,
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/form-data',
      }),
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }

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
    String? subscriptionLevel,
  }) async {
    final data = <String, dynamic>{};
    if (gender != null) data['gender'] = gender;
    if (weight != null) data['weight'] = weight;
    if (subscriptionLevel != null) {
      data['subscription_level'] = subscriptionLevel;
    }

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

  Future<User?> uploadProfilePicture({
    required String token,
    required File file,
  }) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(file.path),
    });

    final response = await _privateClient.dio.patch(
      '/users/me/avatar',
      data: formData,
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/form-data',
      }),
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }
}
