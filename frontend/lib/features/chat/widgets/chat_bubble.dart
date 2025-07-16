// frontend/lib/features/chat/widgets/chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/message.dart';
import '../../../core/models/user.dart';
import '../../ranked/utils/rank_utils.dart';

class ChatBubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final username = author?.username ?? 'Unknown';
    final rank = RankUtils.calculateRank(energy.toDouble(), null);
    final rankColor = RankUtils.getRankColor(rank);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                username,
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 4),
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
}
