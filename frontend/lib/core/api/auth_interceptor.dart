// frontend/lib/core/api/auth_interceptor.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_providers.dart'
    show publicHttpClientProvider, privateHttpClientProvider, authTokenProvider;
import '../providers/auth_provider.dart' show authProvider;
import '../providers/secure_storage_provider.dart' show secureStorageProvider;

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  Future<void>? _refreshing;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = _ref.read(authTokenProvider);
    if (token == null || token.isEmpty) {
      debugPrint(
          "AuthInterceptor: No token for ${options.method} ${options.path} -> blocking");
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          message: "Authentication token not available. Request blocked.",
        ),
      );
    }

    options.headers['Authorization'] = 'Bearer $token';
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode ?? 0;
    final alreadyRetried = err.requestOptions.extra['__retried__'] == true;
    if (status == 401 && !alreadyRetried) {
      try {
        _refreshing ??= _doRefresh();
        await _refreshing;
      } catch (e) {
        debugPrint("AuthInterceptor: refresh failed: $e");
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
        } catch (retryErr, st) {
          debugPrint("AuthInterceptor: retry failed: $retryErr\n$st");
          return handler.reject(err);
        }
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
          debugPrint("AuthInterceptor: refresh succeeded");
          return;
        }
      }

      await storage.deleteToken();
      await _ref.read(authProvider.notifier).logout();
      throw Exception("Refresh endpoint returned no token");
    } catch (e, st) {
      debugPrint("AuthInterceptor: refresh error: $e\n$st");
      await storage.deleteToken();
      await _ref.read(authProvider.notifier).logout();
      rethrow;
    }
  }
}
