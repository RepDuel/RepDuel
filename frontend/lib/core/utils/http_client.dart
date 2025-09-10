// frontend/lib/core/utils/http_client.dart

import 'package:dio/dio.dart';

class HttpClient {
  final Dio _dio;

  HttpClient(this._dio);

  // Expose the underlying Dio instance if needed elsewhere
  Dio get dio => _dio;

  // Your existing GET method
  Future<Response> get(String path, {Options? options}) {
    return _dio.get(path, options: options);
  }

  // Your existing POST method
  Future<Response> post(String path, {Object? data, Options? options}) {
    return _dio.post(path, data: data, options: options);
  }

  // Your existing PATCH method
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // --- FINAL SAFE VERSION ---
  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
