// frontend/lib/core/http/adapter_io.dart

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

/// No special adapter needed on mobile/desktop.
void configureDioForPlatform(Dio dio) {
  // Attach an in-memory cookie jar so refresh cookies are stored on mobile.
  final jar = CookieJar();
  dio.interceptors.add(CookieManager(jar));
}
