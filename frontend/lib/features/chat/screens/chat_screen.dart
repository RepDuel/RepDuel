// frontend/lib/features/chat/screens/chat_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/config/env.dart';
import 'package:frontend/core/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/message.dart';
import '../../../core/models/user.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../../../widgets/main_bottom_nav_bar.dart';

// Message wrapper with all fields enriched (matches backend broadcast format)
class ChatDisplayMessage {
  final Message message;
  final User user;
  final String rankColor;
  final String rankIconPath;

  ChatDisplayMessage({
    required this.message,
    required this.user,
    required this.rankColor,
    required this.rankIconPath,
  });

  factory ChatDisplayMessage.fromJson(Map<String, dynamic> json) {
    return ChatDisplayMessage(
      message: Message.fromJson(json['message']),
      user: User.fromJson(json['user']),
      rankColor: json['rankColor'] ?? '#00ced1',
      rankIconPath: json['rankIconPath'] ?? 'assets/images/ranks/unranked.svg',
    );
  }
}

// Provider to load message history once on app start
final chatHistoryProvider =
    FutureProvider<List<ChatDisplayMessage>>((ref) async {
  final auth = ref.read(authStateProvider);
  final token = auth.token;

  final res = await http.get(
    Uri.parse('${Env.baseUrl}/api/v1/history/global'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (res.statusCode != 200) throw Exception('Failed to load chat history');

  final List raw = jsonDecode(res.body);
  return raw.map((e) => ChatDisplayMessage.fromJson(e)).toList();
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late WebSocketChannel channel;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatDisplayMessage> _messages = [];

  // Cache auth data (so we don’t use ref after dispose)
  late final String? _token;
  late final String? _userId;

  bool _connected = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider);
    _token = auth.token;
    _userId = auth.user?.id;
    _initChatWebSocket();
  }

  void _initChatWebSocket() {
    final token = _token;
    if (token == null || token.isEmpty) return;

    channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/api/v1/ws/chat/global?token=$token'),
    );

    channel.stream.listen((data) {
      if (!mounted) return;
      try {
        final json = jsonDecode(data);
        final message = ChatDisplayMessage.fromJson(json);
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      } catch (e) {
        debugPrint('WS parse error: $e');
      }
    }, onError: (err) {
      debugPrint('WebSocket error: $err');
      if (mounted) context.pop();
    }, onDone: () {
      debugPrint('WebSocket closed');
    });

    _connected = true;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || !_connected) return;

    final payload = {
      'content': text,
      'authorId': _userId,
      'channelId': '00000000-0000-0000-0000-000000000000',
    };

    try {
      channel.sink.add(jsonEncode(payload));
      _controller.clear();
    } catch (e) {
      debugPrint('Send error: $e');
    }
  }

  @override
  void dispose() {
    try {
      channel.sink.close(1000, 'Client closed');
    } catch (_) {}
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
      body: ref.watch(chatHistoryProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading chat: $e')),
            data: (initialMessages) {
              // Load only once, then append live
              if (_messages.isEmpty) _messages.addAll(initialMessages);

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final isMe = m.message.authorId == currentUser?.id;
                        return ChatBubble(
                          message: m.message.content,
                          color: m.rankColor,
                          rankIconPath: m.rankIconPath,
                          displayName: m.user.username,
                          avatarUrl: m.user.avatarUrl ?? '',
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
              );
            },
          ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 3,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/normal');
              break;
            case 1:
              context.go('/ranked');
              break;
            case 2:
              context.go('/routines');
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
