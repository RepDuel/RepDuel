// frontend/lib/features/chat/screens/channel_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/message_socket_service.dart';
import '../providers/message_list_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input_bar.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  MessageSocketService? _socketService;
  final TextEditingController _controller = TextEditingController();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    print('ChannelScreen.initState() called for channelId: ${widget.channelId}');
    _initializeSocket();
  }

  Future<void> _initializeSocket() async {
    print('Initializing WebSocket connection...');
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      print('No authenticated user found, aborting WebSocket initialization.');
      return;
    }

    print('Attempting to read auth token from storage...');
    final token = await _storage.read(key: 'auth_token');
    print('Token read from storage: $token');
    if (token == null) {
      print('No auth token found, aborting WebSocket initialization.');
      return;
    }

    const baseUrl = String.fromEnvironment('WS_BASE_URL', defaultValue: 'ws://localhost:8000');
    print('Using WebSocket baseUrl: $baseUrl');
    final socket = MessageSocketService(baseUrl: baseUrl, token: token);
    print('Connecting to WebSocket with channelId: ${widget.channelId}');
    socket.connect(widget.channelId);
    _socketService = socket;

    socket.messages.listen((data) {
      try {
        print('Received message from WebSocket stream: $data');
        final message = data;
        ref.read(messageListProvider(widget.channelId).notifier).addMessage(message);
      } catch (e, stack) {
        print('Error processing incoming message: $e\n$stack');
      }
    }, onError: (error) {
      print('WebSocket stream error: $error');
    }, onDone: () {
      print('WebSocket stream closed');
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _socketService == null) {
      print('Attempted to send empty message or socket not connected.');
      return;
    }

    final payload = jsonEncode({
      'content': text,
      'channel_id': widget.channelId,
    });

    print('Sending message: $payload');
    _socketService!.sendMessage(payload);
    _controller.clear();
  }

  @override
  void dispose() {
    print('Disposing ChannelScreen and disconnecting WebSocket');
    _socketService?.disconnect();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final messageListAsync = ref.watch(messageListProvider(widget.channelId));

    return Scaffold(
      appBar: AppBar(title: const Text('Channel')),
      body: Column(
        children: [
          Expanded(
            child: messageListAsync.when(
              data: (messages) {
                print('Rendering ${messages.length} messages');
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = user?.id == message.authorId;
                    return ChatBubble(message: message, isMe: isMe);
                  },
                );
              },
              loading: () {
                print('Loading messages...');
                return const Center(child: CircularProgressIndicator());
              },
              error: (e, _) {
                print('Error loading messages: $e');
                return Center(child: Text('Error: $e'));
              },
            ),
          ),
          MessageInputBar(
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
