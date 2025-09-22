// frontend/lib/core/providers/user_by_username_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'api_providers.dart';

/// Fetch a user's public profile by username.
final userByUsernameProvider =
    FutureProvider.autoDispose.family<User, String>((ref, username) async {
  final client = ref.watch(publicHttpClientProvider);
  final response = await client.get('/users/username/$username');

  if (response.statusCode == 404) {
    throw Exception('User not found');
  }

  if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  throw Exception('Failed to load user $username');
});
