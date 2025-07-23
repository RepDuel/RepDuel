// frontend/lib/features/chat/widgets/chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/models/message.dart';
import '../../../core/models/user.dart';

class ChatBubble extends ConsumerWidget {
  final Message message;
  final bool isMe;
  final User? author;
  final int energy;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.author,
    required this.energy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = author?.username ?? 'Unknown';
    final avatarUrl = author?.avatarUrl ?? '';
    final rank = _getRankFromEnergy(energy);
    final rankColor = _getRankColor(rank);
    final rankIconPath = 'assets/images/ranks/${rank.toLowerCase()}.svg';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : const AssetImage('assets/images/profile_placeholder.png')
                      as ImageProvider,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(username,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: rankColor)),
                      const SizedBox(width: 6),
                      SvgPicture.asset(rankIconPath, height: 18, width: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('h:mm a').format(message.createdAt.toLocal()),
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _getRankFromEnergy(int energy) {
    if (energy >= 1200) return 'Celestial';
    if (energy >= 1100) return 'Astra';
    if (energy >= 1000) return 'Nova';
    if (energy >= 900) return 'Grandmaster';
    if (energy >= 800) return 'Master';
    if (energy >= 700) return 'Jade';
    if (energy >= 600) return 'Diamond';
    if (energy >= 500) return 'Platinum';
    if (energy >= 400) return 'Gold';
    if (energy >= 300) return 'Silver';
    if (energy >= 200) return 'Bronze';
    return 'Iron';
  }

  Color _getRankColor(String rank) {
    switch (rank) {
      case 'Iron':
        return Colors.grey;
      case 'Bronze':
        return const Color(0xFFcd7f32);
      case 'Silver':
        return const Color(0xFFc0c0c0);
      case 'Gold':
        return const Color(0xFFefbf04);
      case 'Platinum':
        return const Color(0xFF00ced1);
      case 'Diamond':
        return const Color(0xFFb9f2ff);
      case 'Jade':
        return const Color(0xFF62f40c);
      case 'Master':
        return const Color(0xFFff00ff);
      case 'Grandmaster':
        return const Color(0xFFffde21);
      case 'Nova':
        return const Color(0xFFa45ee5);
      case 'Astra':
        return const Color(0xFFff4040);
      case 'Celestial':
        return const Color(0xFF00ffff);
      default:
        return Colors.white;
    }
  }
}
