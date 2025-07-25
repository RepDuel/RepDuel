// frontend/lib/features/chat/screens/chat_screen.dart

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
  final ScrollController _scrollController = ScrollController();
  final List<Message> messages = [];
  final Map<String, User> userCache = {};
  final Map<String, String> rankColorCache = {};
  final Map<String, String> rankIconPathCache = {};
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
          final messageData = jsonDecode(data);
          final msg = Message.fromJson(messageData);
          setState(() => messages.add(msg));
          _scrollToBottom();
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
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<User?> _fetchUser(String userId) async {
    if (userCache.containsKey(userId)) {
      return userCache[userId];
    }

    final token = ref.read(authStateProvider).token;
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/v1/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final user = User.fromJson(json);
        userCache[userId] = user;
        return user;
      }
    } catch (e) {
      debugPrint('Failed to fetch user $userId: $e');
    }

    return null;
  }

  Future<String?> _fetchRankColor(String userId) async {
    if (rankColorCache.containsKey(userId)) {
      return rankColorCache[userId];
    }

    final token = ref.read(authStateProvider).token;
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/v1/ranks/rank_color/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final color = jsonDecode(res.body);
        rankColorCache[userId] = color;
        return color;
      }
    } catch (e) {
      debugPrint('Failed to fetch rank color for $userId: $e');
    }

    return null;
  }

  Future<String?> _fetchRankIconPath(String userId) async {
    if (rankIconPathCache.containsKey(userId)) {
      return rankIconPathCache[userId];
    }

    final token = ref.read(authStateProvider).token;
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/v1/ranks/rank_icon/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final path = jsonDecode(res.body);
        rankIconPathCache[userId] = path;
        return path;
      }
    } catch (e) {
      debugPrint('Failed to fetch rank icon for $userId: $e');
    }

    return null;
  }

  void _sendMessage() {
    final content = _controller.text.trim();
    if (content.isNotEmpty && channel != null) {
      final message = {
        'content': content,
        'authorId': ref.read(authStateProvider).user?.id,
        'channelId': '00000000-0000-0000-0000-000000000000',
      };

      channel!.sink.add(jsonEncode(message));
      _controller.clear();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    channel?.sink.close(1000, 'Client closed connection');
    _controller.dispose();
    _scrollController.dispose();
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
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return FutureBuilder<User?>(
                  future: _fetchUser(message.authorId),
                  builder: (context, userSnapshot) {
                    final user = userSnapshot.data;
                    return FutureBuilder<String?>(
                      future: _fetchRankColor(message.authorId),
                      builder: (context, colorSnapshot) {
                        final color = colorSnapshot.data ?? '#00ced1';
                        return FutureBuilder<String?>(
                          future: _fetchRankIconPath(message.authorId),
                          builder: (context, iconSnapshot) {
                            final iconPath = iconSnapshot.data ??
                                'assets/images/ranks/unranked.svg';
                            final isMe = message.authorId ==
                                ref.read(authStateProvider).user?.id;

                            return ChatBubble(
                              message: message.content,
                              color: color,
                              rankIconPath: iconPath,
                              displayName: user?.username ?? 'Unknown',
                              avatarUrl: user?.avatarUrl ?? '',
                              isMe: isMe,
                            );
                          },
                        );
                      },
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
