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
    debugPrint('ChannelScreen.initState() called for channelId: ${widget.channelId}'); // Changed to debugPrint
    _initializeSocket();
  }

  Future<void> _initializeSocket() async {
    debugPrint('Initializing WebSocket connection...'); // Changed to debugPrint
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      debugPrint('No authenticated user found, aborting WebSocket initialization.'); // Changed to debugPrint
      return;
    }

    debugPrint('Attempting to read auth token from storage...'); // Changed to debugPrint
    final token = await _storage.read(key: 'auth_token');
    debugPrint('Token read from storage: $token'); // Changed to debugPrint
    if (token == null) {
      debugPrint('No auth token found, aborting WebSocket initialization.'); // Changed to debugPrint
      return;
    }

    const baseUrl = String.fromEnvironment('WS_BASE_URL', defaultValue: 'ws://localhost:8000');
    debugPrint('Using WebSocket baseUrl: $baseUrl'); // Changed to debugPrint
    final socket = MessageSocketService(baseUrl: baseUrl, token: token);
    debugPrint('Connecting to WebSocket with channelId: ${widget.channelId}'); // Changed to debugPrint
    socket.connect(widget.channelId);
    _socketService = socket;

    socket.messages.listen((data) {
      try {
        debugPrint('Received message from WebSocket stream: $data'); // Changed to debugPrint
        final message = data;
        ref.read(messageListProvider(widget.channelId).notifier).addMessage(message);
      } catch (e, stack) {
        debugPrint('Error processing incoming message: $e\n$stack'); // Changed to debugPrint
      }
    }, onError: (error) {
      debugPrint('WebSocket stream error: $error'); // Changed to debugPrint
    }, onDone: () {
      debugPrint('WebSocket stream closed'); // Changed to debugPrint
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _socketService == null) {
      debugPrint('Attempted to send empty message or socket not connected.'); // Changed to debugPrint
      return;
    }

    final payload = jsonEncode({
      'content': text,
      'channel_id': widget.channelId,
    });

    debugPrint('Sending message: $payload'); // Changed to debugPrint
    _socketService!.sendMessage(payload);
    _controller.clear();
  }

  @override
  void dispose() {
    debugPrint('Disposing ChannelScreen and disconnecting WebSocket'); // Changed to debugPrint
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
                debugPrint('Rendering ${messages.length} messages'); // Changed to debugPrint
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
                debugPrint('Loading messages...'); // Changed to debugPrint
                return const Center(child: CircularProgressIndicator());
              },
              error: (e, _) {
                debugPrint('Error loading messages: $e'); // Changed to debugPrint
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