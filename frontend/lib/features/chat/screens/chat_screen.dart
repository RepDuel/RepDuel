// frontend/lib/features/chat/screens/chat_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../../../core/models/user.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../../widgets/main_bottom_nav_bar.dart';
import 'package:go_router/go_router.dart';

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
  int currentUserEnergy = 0;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final auth = ref.read(authStateProvider);
    final token = auth.token;
    currentUser = auth.user;

    if (currentUser != null) {
      await _fetchCurrentUserEnergy(currentUser!.id);
    }

    if (token != null && token.isNotEmpty) {
      channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/api/v1/ws/chat/global?token=$token'),
      );

      channel!.stream.listen((text) {
        final now = DateTime.now();
        final msg = Message(
          id: 'remote-${now.millisecondsSinceEpoch}',
          content: text,
          authorId: 'other-user',
          channelId: 'global',
          createdAt: now,
          updatedAt: now,
        );
        setState(() => messages.add(msg));
      }, onError: (e) {
        debugPrint('WebSocket error: $e');
        if (mounted) {
          context.pop(); // return to previous screen on failure
        }
      });

      await _loadHistory();
    } else {
      debugPrint('Missing JWT token. Cannot connect to chat.');
    }
  }

  Future<void> _fetchCurrentUserEnergy(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/v1/energy/latest/$userId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          currentUserEnergy = int.tryParse(response.body) ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch energy: $e');
    }
  }

  Future<void> _loadHistory() async {
    final token = ref.read(authStateProvider).token;

    if (token == null || token.isEmpty) {
      debugPrint('Cannot load history without token.');
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
      } else {
        debugPrint('Failed to load chat history: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  void _sendMessage() {
    final c = _controller.text.trim();
    if (c.isNotEmpty && channel != null) {
      channel!.sink.add(c);
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
                  message: message,
                  isMe: isMe,
                  author: currentUser,
                  energy: currentUserEnergy,
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
