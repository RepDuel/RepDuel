// frontend/lib/features/home/providers/guild_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/guild.dart';
import '../../../core/providers/api_providers.dart';

final myGuildsProvider = FutureProvider<List<Guild>>((ref) async {
  final client = ref.read(privateHttpClientProvider);
  final res = await client.get('/guilds/me');

  final data = res.data as List<dynamic>;
  return data.map((e) => Guild.fromJson(e as Map<String, dynamic>)).toList();
});
