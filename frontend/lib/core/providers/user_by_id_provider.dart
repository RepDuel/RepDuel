// frontend/lib/core/providers/user_by_id_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'api_providers.dart';

/// Fetch a user's public profile by ID (requires auth).
final userByIdProvider = FutureProvider.autoDispose.family<User, String>((ref, userId) async {
  final client = ref.watch(privateHttpClientProvider);
  final res = await client.get('/users/$userId');
  if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
    return User.fromJson(res.data as Map<String, dynamic>);
  }
  throw Exception('Failed to load user $userId');
});

