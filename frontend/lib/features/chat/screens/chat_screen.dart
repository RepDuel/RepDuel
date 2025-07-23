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

  Future<User> _fetchUser(String authorId) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/v1/users/$authorId'),
      );
      if (response.statusCode == 200) {
        final userJson = jsonDecode(response.body);
        final user = User.fromJson({
          'id': userJson['id'],
          'username': userJson['username'],
          'email': userJson['email'] ?? 'Unknown',
          'is_active': userJson['is_active'] ?? true,
          'created_at': userJson['created_at'],
          'updated_at': userJson['updated_at'],
          'avatar_url': userJson['avatar_url'] ?? '',
        });
        return user;
      } else {
        return User(
          id: authorId,
          username: 'Unknown',
          email: 'Unknown',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          avatarUrl: '',
        );
      }
    } catch (e) {
      return User(
        id: authorId,
        username: 'Unknown',
        email: 'Unknown',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        avatarUrl: '',
      );
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

                return FutureBuilder<User>(
                  future: _fetchUser(message.authorId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return const Text('Error fetching user');
                    }
                    final user = snapshot.data!;
                    return ChatBubble(
                      message: message.content,
                      color: '#00ced1', // Placeholder for color
                      rankIconPath:
                          'assets/images/ranks/diamond.svg', // Placeholder for rank icon path
                      displayName: user.username,
                      avatarUrl: user.avatarUrl ?? '',
                      isMe: isMe,
                    );
                  },
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
