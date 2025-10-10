// frontend/lib/core/utils/http_client.dart

import 'package:dio/dio.dart';

class HttpClient {
  final Dio _dio;

  HttpClient(this._dio);

  Dio get dio => _dio;

  String _resolvePath(String path) {
    if (path.isEmpty) {
      return path;
    }

    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return trimmed.replaceFirst(RegExp(r'^/+'), '');
    }

    return trimmed;
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(
      _resolvePath(path),
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> post(String path, {Object? data, Options? options}) {
    return _dio.post(
      _resolvePath(path),
      data: data,
      options: options,
    );
  }

  Future<Response> put(String path, {Object? data, Options? options}) {
    return _dio.put(
      _resolvePath(path),
      data: data,
      options: options,
    );
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch(
      _resolvePath(path),
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete(
      _resolvePath(path),
      queryParameters: queryParameters,
      options: options,
    );
  }
}
