import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../../../core/models/message.dart';
import '../../../widgets/main_bottom_nav_bar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8000/ws/chat/global'),
  );

  final TextEditingController _controller = TextEditingController();
  final List<Message> messages = [];

  // TEMP user ID; replace with actual auth integration
  final String currentUserId = 'my-user-id';

  void _sendMessage() {
    final content = _controller.text.trim();
    if (content.isNotEmpty) {
      final now = DateTime.now();
      final myMessage = Message(
        id: 'local-${now.millisecondsSinceEpoch}',
        content: content,
        authorId: currentUserId,
        channelId: 'global',
        createdAt: now,
        updatedAt: now,
      );
      channel.sink.add(content);
      setState(() {
        messages.add(myMessage);
      });
      _controller.clear();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/v1/chat/history/global'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final history = data.map((json) => Message.fromJson(json)).toList();
        setState(() {
          messages.insertAll(0, history);
        });
      } else {
        debugPrint('Failed to load chat history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();

    channel.stream.listen((messageText) {
      final now = DateTime.now();
      final msg = Message(
        id: 'remote-${now.millisecondsSinceEpoch}',
        content: messageText,
        authorId: 'other-user', // update this if using real user IDs
        channelId: 'global',
        createdAt: now,
        updatedAt: now,
      );
      setState(() {
        messages.add(msg);
      });
    });
  }

  @override
  void dispose() {
    channel.sink.close();
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
                final isMe = message.authorId == currentUserId;
                return ChatBubble(message: message, isMe: isMe);
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
              break; // already here
            case 4:
              context.go('/profile');
              break;
          }
        },
      ),
    );
  }
}
