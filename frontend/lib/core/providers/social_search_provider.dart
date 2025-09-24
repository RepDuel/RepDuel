// frontend/lib/core/providers/social_search_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_user.dart';
import 'api_providers.dart';

final socialSearchQueryProvider =
    StateProvider.autoDispose<String>((ref) => '');

final socialSearchResultsProvider =
    FutureProvider.autoDispose.family<SocialSearchResults, String>(
  (ref, query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return SocialSearchResults.empty();
    }

    final client = ref.watch(privateHttpClientProvider);
    final response = await client.get(
      '/users/lookup',
      queryParameters: {'q': trimmed},
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      return SocialSearchResults.fromJson(
        response.data as Map<String, dynamic>,
      );
    }

    final message = response.statusMessage ?? 'Search failed. Please try again.';
    throw Exception(message);
  },
);
