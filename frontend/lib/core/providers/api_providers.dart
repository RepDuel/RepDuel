// lib/core/providers/api_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

import '../api/api_client.dart';
import '../api/auth_api_service.dart';
import '../api/guild_api_service.dart';
import '../services/secure_storage_service.dart';
import '../api/message_api_service.dart';
import '../utils/http_client.dart';
import 'auth_provider.dart'; // import to access authProvider

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
      connectTimeout: const Duration(seconds: 5), // Added const
      receiveTimeout: const Duration(seconds: 3), // Added const
    ),
  );

  // Watch the token once here so it updates when token changes
  final token = ref.watch(authProvider).token;

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('Adding Authorization header with token: $token'); // Changed to debugPrint
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          debugPrint('No valid token found, not adding Authorization header'); // Changed to debugPrint
        }
        debugPrint('Request headers: ${options.headers}'); // Changed to debugPrint
        return handler.next(options);
      },
      onError: (DioException error, handler) { // Changed DioError to DioException
        debugPrint('Request error: ${error.response?.statusCode} - ${error.message}'); // Changed to debugPrint
        return handler.next(error);
      },
      onResponse: (response, handler) {
        debugPrint('Response received: ${response.statusCode} ${response.data}'); // Changed to debugPrint
        return handler.next(response);
      },
    ),
  );

  return HttpClient(dio);
});

final messageApiProvider = Provider<MessageApiService>((ref) {
  final httpClient = ref.read(httpClientProvider);
  return MessageApiService(httpClient);
});
