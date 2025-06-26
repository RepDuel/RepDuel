import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../providers/api_providers.dart'; // For authTokenProvider

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authTokenProvider);
    debugPrint('AuthInterceptor: Checking token for private request.');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      debugPrint('AuthInterceptor: Token added to header.');
    } else {
      debugPrint('AuthInterceptor: No token found.');
    }
    super.onRequest(options, handler);
  }
}