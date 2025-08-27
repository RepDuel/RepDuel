// frontend/lib/core/api/auth_interceptor.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint; // For logging
import 'package:flutter_riverpod/flutter_riverpod.dart'; // For Ref

// Assuming auth_provider.dart and api_providers.dart are correctly set up as discussed.
// Import the provider that gives us the token safely.
import '../providers/api_providers.dart' show authTokenProvider; 

// AuthInterceptor now requires a Ref to access Riverpod providers.
class AuthInterceptor extends Interceptor {
  final Ref _ref; // Inject Ref to access other providers

  // Constructor to receive the Ref.
  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Get the token safely using the authTokenProvider.
    // authTokenProvider is designed to return null if auth is loading, errored, or logged out.
    final token = _ref.read(authTokenProvider); 

    // --- Production-Ready Blocking Logic ---
    // If token is null, it means authentication is not ready or failed.
    // As per industry standards and the discussed "Elon Musk" approach,
    // we block requests that require authentication.
    if (token == null) {
      // Log this for debugging purposes.
      debugPrint("AuthInterceptor: Token not available (auth loading/error/logged out). Blocking request to ${options.path}");
      
      // Reject the request with a DioException.
      // This signals to Dio and the caller that the request failed due to auth.
      return handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.unknown, // Use a generic type for auth issues
        message: "Authentication token not available. Request blocked.",
      ));
      
      // If you wanted to proceed without a token (less secure default), 
      // you would simply call: return handler.next(options);
      // But blocking is generally preferred for security and predictability.
    }

    // If a token is available, add it to the Authorization header.
    options.headers['Authorization'] = 'Bearer $token';
    
    // Proceed with the request.
    return handler.next(options);
  }
}

/*
// NOTE: The provider for AuthInterceptor itself is defined in api_providers.dart
// This is how it would look there:

// In api_providers.dart:

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  // Pass the Ref to the interceptor so it can access authTokenProvider.
  return AuthInterceptor(ref); 
});

// And then used in privateHttpClientProvider:
final privateHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  // Add the AuthInterceptor using the provider.
  dio.interceptors.add(ref.read(authInterceptorProvider)); 
  return HttpClient(dio);
});
*/