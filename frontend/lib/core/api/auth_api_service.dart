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

  // --- THIS IS THE FIX ---
  Future<User?> getMe({String? token}) async {
    // This call is special. It's used for the initial auth check.
    // To avoid the interceptor race condition, we use the PUBLIC client
    // and manually add the Authorization header.
    
    // If no token is provided, we can't get the user.
    if (token == null || token.isEmpty) {
      return null;
    }

    // Manually create the options with the auth header.
    final options = Options(headers: {'Authorization': 'Bearer $token'});

    // Use the _publicClient to bypass our AuthInterceptor.
    final response = await _publicClient.get('/users/me', options: options);

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }
  // --- END OF FIX ---


  // All other private calls below will continue to use the _privateClient
  // and its interceptor, which is correct for calls made *after* login.

  Future<User?> updateUser({
    required String token, // 'token' here is mostly for legacy calls, the interceptor handles it.
    required Map<String, dynamic> updates,
  }) async {
    // The private client's interceptor will add the token automatically.
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
    required String token, // Legacy, not strictly needed with the interceptor
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

    // Use the private client's raw dio instance for multipart, but the interceptor is still part of it.
    final response = await _privateClient.dio.patch(
      '/users/me/avatar',
      data: formData,
      options: Options(
        // The interceptor will add the token, so we only need to set the content type.
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );

    if (response.statusCode == 200) {
      return User.fromJson(response.data);
    }
    return null;
  }

  // I am removing the other duplicate/legacy methods like updateMe, uploadAvatar, etc.
  // to clean up the service. The methods `updateUser` and `uploadProfilePictureFromBytes`
  // are the primary ones being used by our corrected AuthNotifier.
}