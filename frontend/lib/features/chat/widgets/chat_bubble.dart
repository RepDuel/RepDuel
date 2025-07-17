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
      alignment: Alignment.centerLeft, // Always align to the left
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        width: double.infinity, // Full width of the screen
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Always start (left)
          children: [
            // Row to display username and timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Username text
                Text(
                  username,
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Timestamp text
                Text(
                  DateFormat('h:mm a').format(message.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[300],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Message content
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
