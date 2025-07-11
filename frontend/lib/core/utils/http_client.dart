import 'package:dio/dio.dart';

class HttpClient {
  final Dio _dio;

  HttpClient(this._dio);

  Dio get dio => _dio;

  Future<Response> get(String path, {Options? options}) {
    return _dio.get(path, options: options);
  }

  Future<Response> post(String path, {Object? data, Options? options}) {
    return _dio.post(path, data: data, options: options);
  }

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
}
