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

class ChatDisplayMessage {
  final Message message;
  final User? user;
  final String rankColor;
  final String rankIconPath;

  ChatDisplayMessage({
    required this.message,
    this.user,
    required this.rankColor,
    required this.rankIconPath,
  });
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  WebSocketChannel? channel;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatDisplayMessage> displayMessages = [];
  final Map<String, User> userCache = {};
  final Map<String, String> rankColorCache = {};
  final Map<String, String> rankIconPathCache = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final auth = ref.read(authStateProvider);
    final token = auth.token;

    if (token != null && token.isNotEmpty) {
      channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/api/v1/ws/chat/global?token=$token'),
      );

      channel!.stream.listen((data) async {
        try {
          final messageData = jsonDecode(data);
          final msg = Message.fromJson(messageData);
          final enriched = await _enrichMessage(msg);
          if (!mounted) return;
          setState(() {
            displayMessages.add(enriched);
          });
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

    if (token == null || token.isEmpty) return;

    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/v1/history/global'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final hist = (jsonDecode(res.body) as List)
            .map((j) => Message.fromJson(j))
            .toList();

        final enrichedList = await Future.wait(hist.map(_enrichMessage));
        if (!mounted) return;
        setState(() {
          displayMessages.addAll(enrichedList);
          isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<ChatDisplayMessage> _enrichMessage(Message msg) async {
    final user = await _fetchUser(msg.authorId);
    final color = await _fetchRankColor(msg.authorId) ?? '#00ced1';
    final iconPath = await _fetchRankIconPath(msg.authorId) ??
        'assets/images/ranks/unranked.svg';

    return ChatDisplayMessage(
      message: msg,
      user: user,
      rankColor: color,
      rankIconPath: iconPath,
    );
  }

  Future<User?> _fetchUser(String userId) async {
    if (userCache.containsKey(userId)) return userCache[userId];

    final token = ref.read(authStateProvider).token;
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/v1/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final user = User.fromJson(jsonDecode(res.body));
        userCache[userId] = user;
        return user;
      }
    } catch (e) {
      debugPrint('Failed to fetch user $userId: $e');
    }

    return null;
  }

  Future<String?> _fetchRankColor(String userId) async {
    if (rankColorCache.containsKey(userId)) return rankColorCache[userId];

    final token = ref.read(authStateProvider).token;
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('http://localhost:8000/api/v1/ranks/rank_color/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final color = jsonDecode(res.body);
        rankColorCache[userId] = color;
        return color;
      }
    } catch (e) {
      debugPrint('Failed to fetch rank color: $e');
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
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final iconPath = jsonDecode(res.body);
        rankIconPathCache[userId] = iconPath;
        return iconPath;
      }
    } catch (e) {
      debugPrint('Failed to fetch rank icon: $e');
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
    final currentUser = ref.watch(authStateProvider).user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Global Chat'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: displayMessages.length,
                    itemBuilder: (context, index) {
                      final item = displayMessages[index];
                      final isMe = item.message.authorId == currentUser?.id;

                      return ChatBubble(
                        message: item.message.content,
                        color: item.rankColor,
                        rankIconPath: item.rankIconPath,
                        displayName: item.user?.username ?? 'Unknown',
                        avatarUrl: item.user?.avatarUrl ?? '',
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
