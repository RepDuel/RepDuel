// frontend/lib/core/providers/api_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../api/auth_api_service.dart';
import '../api/energy_api_service.dart';
import '../config/env.dart';
import '../services/secure_storage_service.dart';
import '../utils/http_client.dart';
import '../providers/auth_provider.dart';
import '../api/auth_interceptor.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final dioBaseOptionsProvider = Provider<BaseOptions>((ref) => BaseOptions(
      baseUrl: '${Env.baseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

final publicHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  return HttpClient(dio);
});

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor();
});

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

final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.token;
});

final energyApiProvider = Provider<EnergyApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return EnergyApiService(client);
});
