import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/message.dart';
import '../../../core/models/user.dart';
import '../../../core/providers/auth_provider.dart';

import '../widgets/chat_bubble.dart';
import '../widgets/message_input_bar.dart';

import '../../../widgets/main_bottom_nav_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  WebSocketChannel? channel;
  final TextEditingController _controller = TextEditingController();
  final List<Message> messages = [];
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final auth = ref.read(authStateProvider);
    final token = auth.token;
    currentUser = auth.user;

    if (token != null && token.isNotEmpty) {
      channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/api/v1/ws/chat/global?token=$token'),
      );

      channel!.stream.listen((data) {
        try {
          // Expecting a complete JSON-formatted message
          final messageData = jsonDecode(data);
          final msg =
              Message.fromJson(messageData); // Convert JSON to Message object

          setState(() => messages.add(msg)); // Update UI with the new message
        } catch (e) {
          debugPrint('Error parsing WebSocket message: $e');
        }
      }, onError: (e) {
        debugPrint('WebSocket error: $e');
        if (mounted) {
          context.pop();
        }
      });

      await _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final token = ref.read(authStateProvider).token;

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/v1/history/global'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final hist = (jsonDecode(res.body) as List)
            .map((j) => Message.fromJson(j))
            .toList();
        setState(() => messages.insertAll(0, hist));
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  void _sendMessage() {
    final content = _controller.text.trim();
    if (content.isNotEmpty && channel != null) {
      final message = {
        'id':
            'remote-${DateTime.now().millisecondsSinceEpoch}', // Generate a unique message ID
        'content': content, // The message content typed by the user
        'authorId':
            ref.read(authStateProvider).user?.id, // Author ID (current user)
        'channelId': 'global', // Channel ID (default to 'global' here)
        'createdAt':
            DateTime.now().toIso8601String(), // Current timestamp for createdAt
        'updatedAt':
            DateTime.now().toIso8601String(), // Current timestamp for updatedAt
      };

      // Send the message as JSON
      channel!.sink.add(jsonEncode(message));
      _controller.clear();
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Global Chat'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe =
                    message.authorId == ref.read(authStateProvider).user?.id;

                return ChatBubble(
                  message: message.content,
                  color: '#00ced1', // Placeholder for color
                  rankIconPath:
                      'assets/images/ranks/diamond.svg', // Placeholder for rank icon path
                  displayName:
                      'Display_Name_Placeholder', // Placeholder for display name
                  avatarUrl: '', // Placeholder for avatar URL
                  isMe: isMe,
                );
              },
            ),
          ),
          MessageInputBar(
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/normal');
              break;
            case 1:
              context.go('/ranked');
              break;
            case 2:
              context.go('/routines');
              break;
            case 3:
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
}
