// frontend/lib/core/providers/api_providers.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_urls.dart';
import '../api/auth_api_service.dart';
import '../api/energy_api_service.dart';
import '../api/guild_api_service.dart';
import '../api/level_api_service.dart';
import '../http/adapter.dart';
import '../http/logging_interceptor.dart';
import '../models/guild.dart';
import '../providers/auth_provider.dart';
import '../providers/secure_storage_provider.dart';
import '../utils/http_client.dart';

final dioBaseOptionsProvider = Provider<BaseOptions>((ref) {
  final base = apiBaseUrl();
  final baseUrl = base.isEmpty
      ? ''
      : base.endsWith('/')
          ? base
          : '$base/';

  return BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    validateStatus: (status) => status != null && status >= 200 && status < 500,
  );
});

final publicHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  configureDioForPlatform(dio);

  if (kDebugMode) {
    dio.interceptors.add(const CompactLoggingInterceptor());
  }

  dio.interceptors.add(GlobalErrorInterceptor(ref));
  return HttpClient(dio);
});

final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.valueOrNull?.token;
});

class AuthInterceptor extends Interceptor {
  final Ref _ref;
  AuthInterceptor(this._ref);

  Future<void>? _refreshing;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = _ref.read(authTokenProvider);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra['__retried__'] == true;

    if (status == 401 && !alreadyRetried) {
      try {
        _refreshing ??= _doRefresh();
        await _refreshing;
      } catch (_) {
        // fall through to reject
      } finally {
        _refreshing = null;
      }

      final newToken = _ref.read(authTokenProvider);
      if (newToken != null && newToken.isNotEmpty) {
        try {
          final orig = err.requestOptions;
          final dio = _ref.read(privateHttpClientProvider).dio;

          final newOptions = Options(
            method: orig.method,
            headers: Map<String, dynamic>.from(orig.headers)
              ..['Authorization'] = 'Bearer $newToken',
            responseType: orig.responseType,
            contentType: orig.contentType,
            followRedirects: orig.followRedirects,
            validateStatus: orig.validateStatus,
            receiveDataWhenStatusError: orig.receiveDataWhenStatusError,
            extra: Map<String, dynamic>.from(orig.extra)
              ..['__retried__'] = true,
          );

          final response = await dio.request<dynamic>(
            orig.path,
            data: orig.data,
            queryParameters: orig.queryParameters,
            options: newOptions,
            cancelToken: orig.cancelToken,
            onSendProgress: orig.onSendProgress,
            onReceiveProgress: orig.onReceiveProgress,
          );

          return handler.resolve(response);
        } catch (_) {}
      }
    }

    return handler.next(err);
  }

  Future<void> _doRefresh() async {
    final publicClient = _ref.read(publicHttpClientProvider);
    final storage = _ref.read(secureStorageProvider);

    try {
      final res = await publicClient.post('/users/refresh');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final map = res.data as Map<String, dynamic>;
        final access = (map['access_token'] as String?) ?? '';
        if (access.isNotEmpty) {
          await storage.writeToken(access);
          await _ref.read(authProvider.notifier).loadUserFromToken();
          return;
        }
      }
      await storage.deleteToken();
      await _ref.read(authProvider.notifier).logout();
      throw Exception('No access token in refresh response');
    } catch (e) {
      await storage.deleteToken();
      await _ref.read(authProvider.notifier).logout();
      rethrow;
    }
  }
}

class GlobalErrorInterceptor extends Interceptor {
  final Ref _ref;
  GlobalErrorInterceptor(this._ref);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      debugPrint(
        '[Dio] Timeout: ${err.requestOptions.method} ${err.requestOptions.uri}',
      );
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

    if (status == 401) {
      debugPrint('[Dio] 401 Unauthorized → logging out user.');
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

    return handler.reject(err);
  }
}

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(ref);
});

final privateHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  configureDioForPlatform(dio);

  dio.interceptors.add(ref.read(authInterceptorProvider));
  dio.interceptors.add(GlobalErrorInterceptor(ref));

  if (kDebugMode) {
    dio.interceptors.add(const CompactLoggingInterceptor());
  }

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

final energyApiProvider = Provider<EnergyApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return EnergyApiService(client);
});

final levelApiProvider = Provider<LevelApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return LevelApiService(client);
});

final myGuildsProvider = FutureProvider<List<Guild>>((ref) async {
  final guildService = ref.watch(guildApiProvider);
  return guildService.getMyGuilds();
});
