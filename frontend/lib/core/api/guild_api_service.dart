import '../models/guild.dart';
import '../utils/http_client.dart';

class GuildApiService {
  final HttpClient _client;

  GuildApiService(this._client);

  Future<List<Guild>> getMyGuilds() async {
    final response = await _client.get('/guilds/');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data;
      return jsonList.map((json) => Guild.fromJson(json)).toList();
    }

    return [];
  }

  Future<Guild?> createGuild(String name) async {
    final response = await _client.post(
      '/guilds/',
      data: {'name': name},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Guild.fromJson(response.data);
    }

    return null;
  }
}