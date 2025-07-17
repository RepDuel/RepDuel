import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/message.dart';
import '../../../core/models/user.dart';

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
    final avatarUrl = author?.avatarUrl ?? ''; // Get the avatar URL
    final rankColor = Colors.blue; // Change or calculate rank color as needed

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
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rankColor, // You can use rankColor here if needed
                    ),
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
}
