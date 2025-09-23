// frontend/lib/core/providers/quests_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quest.dart';
import 'api_providers.dart';
import 'auth_provider.dart';

final questsProvider =
    FutureProvider.autoDispose<List<QuestInstance>>((ref) async {
  final authState = ref.watch(authProvider);
  final token = authState.valueOrNull?.token;

  if (token == null || token.isEmpty) {
    throw Exception('Authentication token not available. Please log in.');
  }

  final client = ref.read(privateHttpClientProvider);

  try {
    final response = await client.get('/quests/me');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load quests: HTTP ${response.statusCode} ${response.statusMessage ?? ''}'
            .trim(),
      );
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected quests response format.');
    }

    final questsData = data['quests'];
    if (questsData is! List) {
      return const <QuestInstance>[];
    }

    return questsData
        .whereType<Map>()
        .map((raw) => QuestInstance.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  } catch (error, stack) {
    debugPrint('[questsProvider] Failed to load quests: $error');
    Error.throwWithStackTrace(
        Exception('Failed to load quests: $error'), stack);
  }
});
