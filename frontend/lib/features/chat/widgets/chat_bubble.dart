// frontend/lib/features/chat/widgets/chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/message.dart';
import '../../../core/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final avatarUrl = author?.avatarUrl ?? ''; // Get the avatar URL

    // Fetch the user's energy rank and icon
    final rank = _getRankFromEnergy(energy);
    final rankColor = _getRankColor(rank);
    final rankIconPath = 'assets/images/ranks/${rank.toLowerCase()}.svg';

    return Align(
      alignment: Alignment.centerLeft, // Always align to the left
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Display avatar (profile image)
            CircleAvatar(
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl) // Load from URL
                  : null,
              radius: 16,
            ),
            const SizedBox(width: 8), // Space between avatar and text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rankColor, // Rank color here
                        ),
                      ),
                      const SizedBox(width: 8),
                      SvgPicture.asset(
                        rankIconPath, // Rank icon here
                        height: 20,
                        width: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            // Right aligned timestamp
            Text(
              DateFormat('h:mm a').format(message.createdAt.toLocal()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                  ),
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
        return const Color(0xFFff00ff); // pink
      case 'Grandmaster':
        return const Color(0xFFffde21); // yellow
      case 'Nova':
        return const Color(0xFFa45ee5); // purple
      case 'Astra':
        return const Color(0xFFff4040); // red
      case 'Celestial':
        return const Color(0xFF00ffff); // cyan
      default:
        return Colors.white;
    }
  }
}
