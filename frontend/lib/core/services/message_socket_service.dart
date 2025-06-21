// frontend/lib/core/services/message_socket_service.dart

import 'package:web_socket_channel/web_socket_channel.dart';

class MessageSocketService {
  final String baseUrl; // e.g., ws://localhost:8000
  final String token;
  WebSocketChannel? _channel;

  MessageSocketService({required this.baseUrl, required this.token});

  void connect(String channelId) {
    final url = Uri.parse('$baseUrl/ws/$channelId?token=$token');
    _channel = WebSocketChannel.connect(url);
  }

  void sendMessage(String message) {
    _channel?.sink.add(message);
  }

  Stream<String> get messages =>
      _channel!.stream.map((event) => event.toString());

  void disconnect() {
    _channel?.sink.close();
  }
}
