import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../api/auth_api_service.dart';
import '../api/guild_api_service.dart';
import '../services/secure_storage_service.dart';
import '../api/message_api_service.dart';
import '../utils/http_client.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  const baseUrl = 'http://localhost:8000'; // Replace with your prod URL if needed
  return ApiClient(baseUrl: baseUrl, secureStorage: secureStorage);
});

final authApiProvider = Provider<AuthApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthApiService(client);
});

final guildApiProvider = Provider<GuildApiService>((ref) {
  final client = ref.watch(apiClientProvider);
  return GuildApiService(client);
});


final messageApiProvider = Provider<MessageApiService>((ref) {
  final httpClient = ref.read(httpClientProvider); // You must define this provider too
  return MessageApiService(httpClient);
});


final httpClientProvider = Provider<HttpClient>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000/',
      connectTimeout: Duration(seconds: 5),   // Use Duration here
      receiveTimeout: Duration(seconds: 3),   // Use Duration here
    ),
  );
  return HttpClient(dio);
});
