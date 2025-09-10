// frontend/lib/core/api/auth_interceptor.dart

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_providers.dart'
    show publicHttpClientProvider, privateHttpClientProvider, authTokenProvider;
import '../providers/secure_storage_provider.dart' show secureStorageProvider;
import '../providers/auth_provider.dart' show authProvider;

/// Intercepts requests to attach the access token and
/// handles 401s by refreshing and retrying once.
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  // Gate to prevent multiple simultaneous refresh calls
  Future<void>? _refreshing;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Attach Authorization if we have a token
    final token = _ref.read(authTokenProvider);
    if (token == null || token.isEmpty) {
      // Block private requests with no token (safer default).
      // If you need unauthenticated private calls, replace with: return handler.next(options);
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

    // Only try refresh on 401, and avoid infinite loop by checking a flag.
    final alreadyRetried = err.requestOptions.extra['__retried__'] == true;
    if (status == 401 && !alreadyRetried) {
      try {
        // If a refresh is already in progress, await it; else start one.
        _refreshing ??= _doRefresh();
        await _refreshing;
      } catch (e) {
        // Refresh failed — fall through to reject
        debugPrint("AuthInterceptor: refresh failed: $e");
      } finally {
        // Clear the gate so subsequent 401s can trigger another refresh
        _refreshing = null;
      }

      // After refresh attempt, check if we have a token now
      final newToken = _ref.read(authTokenProvider);
      if (newToken != null && newToken.isNotEmpty) {
        try {
          // Clone original request and retry exactly once
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
          return handler.reject(err); // keep original error
        }
      }
    }

    return handler.next(err);
  }

  /// Performs refresh by calling the public client (sends cookies on web),
  /// storing the new access token, and prompting auth state to reload.
  Future<void> _doRefresh() async {
    final publicClient = _ref.read(publicHttpClientProvider);
    final storage = _ref.read(secureStorageProvider);

    try {
      // POST /users/refresh — cookie is sent automatically by the browser
      final res = await publicClient.post('/users/refresh');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final map = res.data as Map<String, dynamic>;
        final access = (map['access_token'] as String?) ?? '';

        if (access.isNotEmpty) {
          await storage.writeToken(access);
          // Re-hydrate auth state (reads token from storage and fetches /users/me)
          await _ref.read(authProvider.notifier).loadUserFromToken();
          debugPrint("AuthInterceptor: refresh succeeded");
          return;
        }
      }

      // If we get here, treat as failure
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
