import 'dart:convert';

import '../models/guild.dart';
import 'api_client.dart';

class GuildApiService {
  final ApiClient _client;

  GuildApiService(this._client);

  Future<List<Guild>> getMyGuilds() async {
    final response = await _client.get('/guilds/');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Guild.fromJson(json)).toList();
    }

    return [];
  }

  Future<Guild?> createGuild(String name) async {
    final response = await _client.post(
      '/guilds/',
      {'name': name},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Guild.fromJson(json);
    }

    return null;
  }
}
