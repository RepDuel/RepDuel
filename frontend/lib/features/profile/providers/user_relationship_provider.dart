// frontend/lib/features/profile/providers/user_relationship_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/social_user.dart';
import '../../../core/providers/api_providers.dart';

/// Fetch relationship metadata for a user relative to the authenticated viewer.
final userRelationshipProvider =
    FutureProvider.autoDispose.family<SocialUserSummary, String>(
  (ref, userId) async {
    final client = ref.watch(privateHttpClientProvider);
    final response = await client.get('/users/$userId/relationship');

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return SocialUserSummary.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    throw Exception('Failed to load relationship for user $userId');
  },
);
