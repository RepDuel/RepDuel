// frontend/lib/core/api/message_api_service.dart

import 'package:frontend/core/models/message.dart';
import 'package:frontend/core/utils/http_client.dart';

class MessageApiService {
  final HttpClient _client;

  MessageApiService(this._client);

  Future<List<Message>> getMessages(String channelId) async {
    final response = await _client.get('/messages/channel/$channelId');
    final data = response.data as List<dynamic>;
    return data.map((json) => Message.fromJson(json)).toList();
  }
}
