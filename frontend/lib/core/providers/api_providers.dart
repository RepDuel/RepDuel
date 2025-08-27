// frontend/lib/core/providers/api_providers.dart

import 'package:flutter/foundation.dart' show kIsWeb; // Import kIsWeb for conditional logic
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../api/auth_api_service.dart';
import '../api/guild_api_service.dart';
import '../api/energy_api_service.dart';
import '../config/env.dart';
import '../services/secure_storage_service.dart';
import '../utils/http_client.dart';
import '../providers/auth_provider.dart'; // Import the auth provider
import '../api/auth_interceptor.dart';   // Import the auth interceptor
import '../models/guild.dart';          // Import Guild model

// --- Secure Storage ---
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// --- Dio Configuration ---
final dioBaseOptionsProvider = Provider<BaseOptions>((ref) => BaseOptions(
      baseUrl: '${Env.baseUrl}/api/v1',
      // Use longer timeouts for production, though these are examples.
      connectTimeout: const Duration(seconds: 10), 
      receiveTimeout: const Duration(seconds: 10),
    ));

// --- HTTP Clients ---
// Public client: No auth interceptor, for login/register calls.
final publicHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  // Add logging interceptor for debugging if needed in development
  // if (kDebugMode) {
  //   dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  // }
  return HttpClient(dio);
});

// --- Auth Token Provider (Crucial Fix) ---
// This provider safely retrieves the token from authProvider.
final authTokenProvider = Provider<String?>((ref) {
  // Watch the authProvider which returns AsyncValue<AuthState>
  final authStateAsyncValue = ref.watch(authProvider);
  
  // Safely access the token from the AuthState within the AsyncValue.
  // .valueOrNull returns the AuthState if it's in a 'data' state, otherwise null.
  // Then, safely access '.token' from the AuthState.
  return authStateAsyncValue.valueOrNull?.token;
});

// --- Auth Interceptor ---
// The AuthInterceptor needs access to the Ref to get the token provider.
class AuthInterceptor extends Interceptor {
  final Ref _ref; // Inject Ref to access other providers

  AuthInterceptor(this._ref); // Constructor to receive Ref

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Get the token safely using the authTokenProvider.
    final token = _ref.read(authTokenProvider); 

    // IMPORTANT: If auth state is loading or error, token will be null.
    // Per our "Elon Musk" approach, we block requests if the token is null.
    if (token == null) {
      // If auth is loading, we could optionally delay, but blocking is simpler and safer.
      // If auth is errored or logged out, we definitely block.
      debugPrint("AuthInterceptor: Token not found or auth not ready. Blocking request to ${options.path}");
      
      // Option A: Block the request by returning an error.
      // This is the most direct approach to prevent invalid requests.
      return handler.reject(DioException(
        requestOptions: options,
        error: DioExceptionType.unknown, // Use a generic error type
        message: "Authentication token not available.",
      ));
      
      // If you wanted Option B (Proceed without token), you'd just call handler.next(options); here.
      // If you wanted Option C (Delay), it would be much more complex.
    }

    // If token is available, add it to the headers.
    options.headers['Authorization'] = 'Bearer $token';
    return handler.next(options); // Proceed with the request
  }
}

// Provider for the AuthInterceptor itself.
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  // Pass the Ref to the interceptor so it can access authTokenProvider.
  return AuthInterceptor(ref); 
});


// Private client: Uses Dio with the AuthInterceptor.
final privateHttpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(ref.read(dioBaseOptionsProvider));
  // Add the AuthInterceptor using the provider.
  dio.interceptors.add(ref.read(authInterceptorProvider)); 
  
  // Add logging interceptor for debugging if needed in development
  // if (kDebugMode) {
  //   dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  // }
  return HttpClient(dio);
});

// --- API Service Providers ---

final authApiProvider = Provider<AuthApiService>((ref) {
  // Note: AuthApiService might also need to handle auth state itself,
  // but for API calls that require a token, it relies on the HttpClient.
  return AuthApiService(
    publicClient: ref.read(publicHttpClientProvider),
    // Note: passing privateClient here relies on its interceptor.
    // If AuthApiService itself needs auth context, you might pass authProvider or tokenProvider.
    privateClient: ref.read(privateHttpClientProvider), 
  );
});

final guildApiProvider = Provider<GuildApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return GuildApiService(client);
});

final energyApiProvider = Provider<EnergyApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return EnergyApiService(client);
});

// Example of a FutureProvider that uses the authTokenProvider
final myGuildsProvider = FutureProvider<List<Guild>>((ref) async {
  // This FutureProvider will automatically show a loading state if authTokenProvider is null,
  // and the request inside guildService.getMyGuilds() will fail if the interceptor blocks it.
  final guildService = ref.watch(guildApiProvider);
  // This call implicitly uses the privateHttpClient which has the AuthInterceptor.
  return guildService.getMyGuilds(); 
});