import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/message.dart';
import '../../../core/providers/auth_provider.dart'; // Import to get current user
import '../../../core/providers/websocket_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input_bar.dart';

// Provider to manage the list of messages for the current channel
final messageListProvider =
    StateNotifierProvider.autoDispose<MessageListNotifier, List<Message>>(
        (ref) {
  return MessageListNotifier();
});

class MessageListNotifier extends StateNotifier<List<Message>> {
  MessageListNotifier() : super([]);

  void addMessage(Message message) {
    state = [...state, message];
  }

  void addMessages(List<Message> messages) {
    state = [...state, ...messages];
  }
}

class ChannelScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  late final WebSocketService _webSocketService;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _webSocketService = ref.read(webSocketProvider(widget.channelId));
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _webSocketService.connect(
      onMessage: (data) {
        final message = Message.fromJson(data);
        ref.read(messageListProvider.notifier).addMessage(message);
      },
    );
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      _webSocketService.sendMessage({
        'content': content,
        'channel_id': widget.channelId,
      });
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messageListProvider);
    final currentUser = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Channel"),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet. Say hello!'))
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      // Pass the required 'isMe' parameter
                      return ChatBubble(
                        message: message,
                        isMe: message.authorId == currentUser?.id,
                      );
                    },
                  ),
          ),
          // Pass the required 'controller' and 'onSend' parameters
          MessageInputBar(
            controller: _messageController,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
