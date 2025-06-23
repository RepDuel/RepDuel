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
    logger.i('Starting WebSocket connection for channelId: $channelId');
    final token = await secureStorage.readToken();
    if (token == null) {
      logger.w('No token available for WebSocket connection.');
      return;
    }

    final uri = Uri.parse('ws://localhost:8000/ws/messages/$channelId')
        .replace(queryParameters: {'token': token});
    logger.i('Connecting to WebSocket URL: $uri');

    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e, stackTrace) {
      logger.e('Failed to connect to WebSocket', error: e, stackTrace: stackTrace);
      return;
    }

    _channel!.stream.listen(
      (message) {
        logger.i('Received raw message: $message');
        try {
          final data = jsonDecode(message);
          onMessage(data);
        } catch (e, stackTrace) {
          logger.e('Failed to decode WebSocket message', error: e, stackTrace: stackTrace);
        }
      },
      onError: (error, stackTrace) {
        logger.e('WebSocket error', error: error, stackTrace: stackTrace);
      },
      onDone: () {
        logger.i('WebSocket closed.');
      },
      cancelOnError: true,
    );
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      final encoded = jsonEncode(message);
      logger.i('Sending message: $encoded');
      _channel!.sink.add(encoded);
    } else {
      logger.w('WebSocket not connected. Cannot send message.');
    }
  }

  void disconnect() {
    logger.i('Disconnecting WebSocket for channelId: $channelId');
    _channel?.sink.close();
    _channel = null;
  }
}
