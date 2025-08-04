// frontend/lib/features/chat/screens/chat_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/config/env.dart';

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

  // Cache auth data so we don't access `ref` from async callbacks after dispose.
  String? _token;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();

    // Safe to read here; we cache for later async use.
    final auth = ref.read(authStateProvider);
    _token = auth.token;
    _currentUserId = auth.user?.id;

    _initChat();
  }

  Future<void> _initChat() async {
    final token = _token;

    if (token != null && token.isNotEmpty) {
      // Open WS using cached token (no ref access here).
      channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/api/v1/ws/chat/global?token=$token'),
      );

      channel!.stream.listen((data) async {
        // If the widget was disposed while awaiting messages, bail out.
        if (!mounted) return;

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
          // Optional: avoid popping if this screen isn't on top.
          // You can show a SnackBar instead if preferred.
          context.pop();
        }
      });

      await _loadHistory();
    } else {
      // No token -> not logged in; avoid loading/connecting.
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('${Env.baseUrl}/api/v1/history/global'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final hist = (jsonDecode(res.body) as List)
            .map((j) => Message.fromJson(j))
            .toList();

        // Enrich without touching `ref` inside the helpers.
        final enrichedList = await Future.wait(hist.map(_enrichMessage));

        if (!mounted) return;
        setState(() {
          displayMessages.addAll(enrichedList);
          isLoading = false;
        });
        _scrollToBottom();
      } else {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      // If disposed during await, `mounted` will be false; no `ref` access here.
      debugPrint('Error loading chat history: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
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

    final token = _token;
    if (token == null || token.isEmpty) return null;

    try {
      final res = await http.get(
        Uri.parse('${Env.baseUrl}/api/v1/users/$userId'),
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

    final token = _token;
    if (token == null || token.isEmpty) return null;

    try {
      final res = await http.get(
        Uri.parse('${Env.baseUrl}/api/v1/ranks/rank_color/$userId'),
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

    final token = _token;
    if (token == null || token.isEmpty) return null;

    try {
      final res = await http.get(
        Uri.parse('${Env.baseUrl}/api/v1/ranks/rank_icon/$userId'),
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
    if (content.isEmpty || channel == null) return;

    final message = {
      'content': content,
      'authorId': _currentUserId, // use cached id; no `ref.read`
      'channelId': '00000000-0000-0000-0000-000000000000',
    };

    try {
      channel!.sink.add(jsonEncode(message));
      _controller.clear();
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  void _scrollToBottom() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    // Close WS first to stop incoming stream events.
    try {
      channel?.sink.close(1000, 'Client closed connection');
    } catch (_) {}
    channel = null;

    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watching here is safe; build only runs while mounted.
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
