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
  Map<String, User> usersCache =
      {}; // Cache for user data to avoid multiple API calls

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
        // Debug print to check WebSocket message content
        debugPrint('WebSocket message: $text');
        final msg = Message(
          id: 'remote-${now.millisecondsSinceEpoch}',
          content: text,
          authorId: 'other-user', // This is hardcoded as 'other-user' for now
          channelId: 'global',
          createdAt: now,
          updatedAt: now,
        );
        // Debug print to check message content and authorId
        debugPrint(
            'Created message: id = ${msg.id}, authorId = ${msg.authorId}, content = ${msg.content}, createdAt = ${msg.createdAt}');
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
        debugPrint('Loaded ${hist.length} messages from history');

        // Debug print to output full message details
        for (var message in hist) {
          debugPrint(
              'Message details: id = ${message.id}, authorId = ${message.authorId}, content = ${message.content}, createdAt = ${message.createdAt}, updatedAt = ${message.updatedAt}');
        }

        setState(() => messages.insertAll(0, hist));
      } else {
        debugPrint('Failed to load chat history: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<User> _fetchUser(String authorId) async {
    debugPrint('Fetching user details for authorId: $authorId');
    if (usersCache.containsKey(authorId)) {
      debugPrint('User found in cache for authorId: $authorId');
      return usersCache[authorId]!;
    }

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/v1/users/$authorId'),
      );
      if (response.statusCode == 200) {
        final userJson = jsonDecode(response.body);
        debugPrint('Fetched user details for authorId: $authorId');
        final user = User.fromJson({
          'id': userJson['id'],
          'username': userJson['username'],
          'email': userJson['email'] ?? 'Unknown',
          'is_active': userJson['is_active'] ?? true,
          'created_at': userJson['created_at'],
          'updated_at': userJson['updated_at'],
          'avatar_url': userJson['avatar_url'] ?? '', // Add avatar_url
        });
        setState(() {
          usersCache[authorId] = user;
        });
        return user;
      } else {
        debugPrint('Failed to load user details for $authorId');
        return User(
            id: authorId,
            username: 'Unknown',
            email: 'Unknown',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            avatarUrl: ''); // Default avatar_url if no data
      }
    } catch (e) {
      debugPrint('Error loading user details: $e');
      return User(
          id: authorId,
          username: 'Unknown',
          email: 'Unknown',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          avatarUrl: '');
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

                // Debug print for each message being rendered
                debugPrint(
                    'Rendering message: id = ${message.id}, authorId = ${message.authorId}, content = ${message.content}');

                return FutureBuilder<User>(
                  future: _fetchUser(message.authorId), // Fetch user details
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      debugPrint('Waiting for user data...');
                      return const CircularProgressIndicator(); // Show loading while fetching user data
                    }
                    if (snapshot.hasError) {
                      debugPrint('Error fetching user data: ${snapshot.error}');
                      return const Text('Error fetching user');
                    }
                    final user = snapshot.data!;
                    debugPrint(
                        'Rendering message from authorId: ${message.authorId}');
                    return ChatBubble(
                      message: message,
                      isMe: isMe,
                      author:
                          user, // Pass the fetched user details to the ChatBubble
                      energy: currentUserEnergy,
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
