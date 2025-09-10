// frontend/lib/core/providers/api_providers.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
// ✅ Dio v5 browser adapter import:
import 'package:dio/browser.dart' show BrowserHttpClientAdapter;

import '../config/env.dart';
import '../utils/http_client.dart';
import '../api/auth_interceptor.dart';
import 'auth_provider.dart';

/// Shared BaseOptions (same baseUrl for all clients)
final dioBaseOptionsProvider = Provider<BaseOptions>((ref) {
  return BaseOptions(
    baseUrl: '${Env.baseUrl}/api/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  );
});

/// Public client (no Authorization header added automatically)
final publicHttpClientProvider = Provider<HttpClient>((ref) {
  final options = ref.read(dioBaseOptionsProvider);
  final dio = Dio(options);

  // On web, include cookies (needed for refresh-cookie flow)
  if (kIsWeb && dio.httpClientAdapter is BrowserHttpClientAdapter) {
    (dio.httpClientAdapter as BrowserHttpClientAdapter).withCredentials = true;
  }

  return HttpClient(dio);
});

/// Private client (adds Authorization via AuthInterceptor)
final privateHttpClientProvider = Provider<HttpClient>((ref) {
  final options = ref.read(dioBaseOptionsProvider);
  final dio = Dio(options);

  // On web, include cookies (needed so /users/refresh sees the cookie)
  if (kIsWeb && dio.httpClientAdapter is BrowserHttpClientAdapter) {
    (dio.httpClientAdapter as BrowserHttpClientAdapter).withCredentials = true;
  }

  // Attach the auth interceptor (it reads token from authTokenProvider)
  dio.interceptors.add(AuthInterceptor(ref));

  return HttpClient(dio);
});

/// Expose the current access token to interceptors/clients
final authTokenProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider);
  return auth.valueOrNull?.token;
});
