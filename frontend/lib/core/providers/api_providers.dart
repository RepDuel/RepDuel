import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../api/auth_api_service.dart';
import '../api/guild_api_service.dart';
import '../services/secure_storage_service.dart';
import '../api/message_api_service.dart';
import '../utils/http_client.dart';
import 'auth_provider.dart';  // import to access authProvider

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  const baseUrl = 'http://localhost:8000'; // backend base URL
  return ApiClient(baseUrl: baseUrl, secureStorage: secureStorage);
});

final authApiProvider = Provider<AuthApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthApiService(client);
});

final guildApiProvider = Provider<GuildApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return GuildApiService(client);
});

final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.token; // token cached in AuthState
});

final httpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000/',
      connectTimeout: Duration(seconds: 5),
      receiveTimeout: Duration(seconds: 3),
    ),
  );

  // Add an interceptor to attach Authorization header on every request
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get the token from authProvider's current state
        final authState = ref.read(authProvider);
        final token = authState.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ),
  );

  return HttpClient(dio);
});

final messageApiProvider = Provider<MessageApiService>((ref) {
  final httpClient = ref.read(httpClientProvider);
  return MessageApiService(httpClient);
});
