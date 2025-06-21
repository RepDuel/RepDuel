import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

import '../services/secure_storage_service.dart';
import 'package:frontend/core/providers/api_providers.dart';


final logger = Logger();

final webSocketProvider = Provider.family<WebSocketService, String>((ref, channelId) {
  final secureStorage = ref.read(secureStorageProvider);
  return WebSocketService(channelId: channelId, secureStorage: secureStorage);
});

class WebSocketService {
  final String channelId;
  final SecureStorageService secureStorage;
  WebSocketChannel? _channel;

  WebSocketService({
    required this.channelId,
    required this.secureStorage,
  });

  void connect({required void Function(Map<String, dynamic>) onMessage}) async {
    final token = await secureStorage.readToken();
    if (token == null) {
      logger.w('No token available for WebSocket connection.');
      return;
    }

    final uri = Uri.parse('ws://localhost:8000/ws/messages/$channelId')
        .replace(queryParameters: {'token': token});

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        onMessage(data);
      },
      onError: (error) => logger.e('WebSocket error: $error'),
      onDone: () => logger.i('WebSocket closed.'),
    );
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      logger.w('WebSocket not connected.');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
