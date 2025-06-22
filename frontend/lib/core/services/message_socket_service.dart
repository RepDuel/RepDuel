import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/message.dart';

class MessageSocketService {
  final String baseUrl; // e.g., ws://localhost:8000
  final String token;
  WebSocketChannel? _channel;

  final _controller = StreamController<Message>.broadcast();

  MessageSocketService({required this.baseUrl, required this.token});

  void connect(String channelId) {
    final url = Uri.parse('$baseUrl/api/v1/ws/chat/$channelId?token=$token');
    _channel = WebSocketChannel.connect(url);

    _channel!.stream.listen(
      (event) {
        try {
          final data = jsonDecode(event);
          final message = Message.fromJson(data);
          _controller.add(message);
        } catch (e) {
          debugPrint('WebSocket message parse error: $e');
        }
      },
      onError: (error) => debugPrint('WebSocket error: $error'),
      onDone: () => debugPrint('WebSocket closed'),
    );
  }

  void sendMessage(String message) {
    _channel?.sink.add(message);
  }

  Stream<Message> get messages => _controller.stream;

  void disconnect() {
    _channel?.sink.close();
    _controller.close();
  }
}
