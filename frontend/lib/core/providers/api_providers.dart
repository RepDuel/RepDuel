// frontend/lib/core/providers/api_providers.dart

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../api/auth_api_service.dart';
import '../api/guild_api_service.dart';
import '../api/energy_api_service.dart';
import '../config/env.dart';
import '../services/secure_storage_service.dart';
import '../utils/http_client.dart';
import '../providers/auth_provider.dart';
import '../models/guild.dart';

/// ---------------------------
/// Secure Storage
/// ---------------------------
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// ---------------------------
/// Dio Base Options
/// ---------------------------
final dioBaseOptionsProvider = Provider<BaseOptions>((ref) {
  return BaseOptions(
    baseUrl: '${Env.baseUrl}/api/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    // Helpful default headers
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    // Don’t throw for 400–499 by default; we’ll handle in interceptor
    validateStatus: (status) => status != null && status >= 200 && status < 500,
  );
});

/// ---------------------------
/// Public (no auth) client
/// ---------------------------
final publicHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }
  dio.interceptors.add(GlobalErrorInterceptor(ref));
  return HttpClient(dio);
});

/// Token reader (safe across AsyncValue states)
final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.valueOrNull?.token;
});

/// ---------------------------
/// Auth header injector
/// ---------------------------
class AuthInterceptor extends Interceptor {
  final Ref _ref;
  AuthInterceptor(this._ref);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = _ref.read(authTokenProvider);

    // IMPORTANT: Do NOT reject when token is null.
    // Public endpoints (login/register) and some GETs should still proceed.
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}

/// ---------------------------
/// Global error handling
/// ---------------------------
class GlobalErrorInterceptor extends Interceptor {
  final Ref _ref;
  GlobalErrorInterceptor(this._ref);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;

    // Network / timeout: show friendly error, don’t crash UI
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      debugPrint(
          '[Dio] Timeout: ${err.requestOptions.method} ${err.requestOptions.uri}');
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: 'Network timeout. Please try again.',
        ),
      );
    }

    if (err.type == DioExceptionType.connectionError) {
      debugPrint('[Dio] Connection error: ${err.message}');
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: 'No internet connection. Please check your network.',
        ),
      );
    }

    // 401: token expired/invalid -> clean logout (silent) instead of red screen
    if (status == 401) {
      debugPrint('[Dio] 401 Unauthorized → logging out user.');
      // Best-effort logout; don’t await the state change here
      _ref.read(authProvider.notifier).logout();

      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: DioExceptionType.badResponse,
          error: 'Your session expired. Please log in again.',
        ),
      );
    }

    // 403: forbidden
    if (status == 403) {
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: DioExceptionType.badResponse,
          error: 'You do not have permission to perform this action.',
        ),
      );
    }

    // 5xx: server issues
    if (status != null && status >= 500) {
      debugPrint('[Dio] Server error $status: ${err.response?.data}');
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: DioExceptionType.badResponse,
          error: 'Server error. Please try again later.',
        ),
      );
    }

    // Default: pass through (but avoid noisy stack traces)
    return handler.reject(err);
  }
}

/// ---------------------------
/// Private (auth) client
/// ---------------------------
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(ref);
});

final privateHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  dio.interceptors.add(ref.read(authInterceptorProvider));
  dio.interceptors.add(GlobalErrorInterceptor(ref));
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }
  return HttpClient(dio);
});

/// ---------------------------
/// API Service Providers
/// ---------------------------
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

final energyApiProvider = Provider<EnergyApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return EnergyApiService(client);
});

/// Example consumer that benefits from global handling
final myGuildsProvider = FutureProvider<List<Guild>>((ref) async {
  final guildService = ref.watch(guildApiProvider);
  return guildService.getMyGuilds();
});
