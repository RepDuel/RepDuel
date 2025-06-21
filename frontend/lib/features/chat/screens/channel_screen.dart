// frontend/lib/features/chat/screens/channel_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/models/message.dart';
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
  late MessageSocketService _socketService;
  final TextEditingController _controller = TextEditingController();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _setupSocket();
  }

  Future<void> _setupSocket() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    final token = await _storage.read(key: 'authToken'); // Replace with authNotifier.getToken() if defined
    if (token == null) return;

    const baseUrl = String.fromEnvironment('WS_BASE_URL', defaultValue: 'ws://localhost:8000');
    _socketService = MessageSocketService(baseUrl: baseUrl, token: token);
    _socketService.connect(widget.channelId);

    _socketService.messages.listen((data) {
      try {
        final decoded = jsonDecode(data);
        final message = Message.fromJson(decoded);
        ref.read(messageListProvider(widget.channelId).notifier).addMessage(message);
      } catch (_) {
        // Ignore invalid messages
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _socketService.sendMessage(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final messageListAsync = ref.watch(messageListProvider(widget.channelId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messageListAsync.when(
              data: (messages) {
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = user != null && user.id == message.authorId;
                    return ChatBubble(
                      message: message,
                      isMe: isMe,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
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
