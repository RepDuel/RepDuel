import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/auth_api_service.dart';
import '../api/guild_api_service.dart';
import '../services/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  const baseUrl = 'http://localhost:8000/api/v1'; // Replace with your prod URL if needed
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
