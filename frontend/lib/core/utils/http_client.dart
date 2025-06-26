import 'package:dio/dio.dart';

class HttpClient {
  final Dio _dio;

  HttpClient(this._dio);

  Future<Response> get(String path, {Options? options}) {
    return _dio.get(path, options: options);
  }

  // Add the ability to pass 'Options' to the post method
  Future<Response> post(String path, {Object? data, Options? options}) {
    return _dio.post(path, data: data, options: options);
  }
}