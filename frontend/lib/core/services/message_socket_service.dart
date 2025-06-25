// frontend/lib/core/services/message_socket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import '../../core/models/message.dart';

class MessageSocketService {
  final String baseUrl;
  final String token;
  WebSocketChannel? _channel;

  final _controller = StreamController<Message>.broadcast();

  MessageSocketService({required this.baseUrl, required this.token});

  void connect(String channelId) {
    debugPrint('MessageSocketService.connect() called with channelId: $channelId'); // Changed to debugPrint
    final path = '/ws/$channelId?token=$token';
    final url = Uri.parse('$baseUrl$path');
    debugPrint("Connecting to WebSocket: $url"); // Changed to debugPrint

    try {
      _channel = WebSocketChannel.connect(url);
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
      return;
    }

    _channel!.stream.listen(
      (event) {
        try {
          debugPrint('Received raw message: $event'); // Changed to debugPrint
          final data = jsonDecode(event);
          final message = Message.fromJson(data);
          debugPrint('Parsed message: $message'); // Changed to debugPrint
          _controller.add(message);
        } catch (e, stack) {
          debugPrint('WebSocket message parse error: $e\n$stack');
        }
      },
      onError: (error, stackTrace) {
        debugPrint('WebSocket error: $error\n$stackTrace');
      },
      onDone: () {
        debugPrint('WebSocket closed');
      },
      cancelOnError: true,
    );
  }

  void sendMessage(String message) {
    if (_channel == null) {
      debugPrint('WebSocket channel is not connected. Cannot send message.');
      return;
    }
    debugPrint('Sending message: $message'); // Changed to debugPrint
    _channel!.sink.add(message);
  }

  Stream<Message> get messages => _controller.stream;

  void disconnect() {
    debugPrint('Disconnecting WebSocket');
    _channel?.sink.close();
    _controller.close();
  }
}