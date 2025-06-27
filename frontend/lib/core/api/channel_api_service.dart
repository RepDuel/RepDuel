import '../models/channel.dart';
import '../utils/http_client.dart';

class ChannelApiService {
  final HttpClient _client;

  ChannelApiService(this._client);

  Future<List<Channel>> getGuildChannels(String guildId) async {
    final response = await _client.get('/channels/guild/$guildId');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = response.data;
      return jsonList.map((json) => Channel.fromJson(json)).toList();
    }
    return [];
  }
}