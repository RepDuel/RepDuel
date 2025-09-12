import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';

/// On web, use the browser adapter and enable credentials for cookies.
void configureDioForPlatform(Dio dio) {
  final adapter = BrowserHttpClientAdapter();
  adapter.withCredentials = true; // <-- cookies for cross-site (CORS) auth
  dio.httpClientAdapter = adapter;
}
