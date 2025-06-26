import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../api/auth_api_service.dart';
import '../api/guild_api_service.dart';
import '../services/secure_storage_service.dart';
import '../api/message_api_service.dart';
import '../utils/http_client.dart';
import '../providers/auth_provider.dart';
import '../api/auth_interceptor.dart'; // Import the new interceptor

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// Base Dio options for both clients
final dioBaseOptionsProvider = Provider<BaseOptions>((ref) => BaseOptions(
      baseUrl: 'http://localhost:8000/',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

// Client for public endpoints (login, register) - NO interceptor
final publicHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  return HttpClient(dio);
});

// Provider for the custom interceptor
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(ref);
});

// Client for private, authenticated endpoints
final privateHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  dio.interceptors.add(ref.read(authInterceptorProvider));
  return HttpClient(dio);
});

final authApiProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(
    publicClient: ref.read(publicHttpClientProvider),
    privateClient: ref.read(privateHttpClientProvider),
  );
});

final guildApiProvider = Provider<GuildApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return GuildApiService(client);
});

final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.token;
});

final messageApiProvider = Provider<MessageApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return MessageApiService(client);
});