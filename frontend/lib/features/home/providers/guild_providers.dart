// frontend/lib/features/home/providers/guild_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/models/guild.dart';

/// Fetch the current user's guilds as real `Guild` models.
final myGuildsProvider = FutureProvider<List<Guild>>((ref) async {
  final client = ref.read(privateHttpClientProvider); // uses AuthInterceptor
  final res = await client.get('/guilds/me'); // adjust endpoint if different

  // Expecting a JSON array of guilds
  final data = res.data as List<dynamic>;
  return data.map((e) => Guild.fromJson(e as Map<String, dynamic>)).toList();
});
