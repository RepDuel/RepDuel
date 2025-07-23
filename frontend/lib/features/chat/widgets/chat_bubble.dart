import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final String color;
  final String rankIconPath;
  final String displayName;
  final String avatarUrl;
  final bool isMe;

  const ChatBubble({
    super.key,
    required this.message,
    required this.color,
    required this.rankIconPath,
    required this.displayName,
    required this.avatarUrl,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor =
        Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000);

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
                      Text(displayName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: rankColor)),
                      const SizedBox(width: 6),
                      SvgPicture.asset(rankIconPath, height: 18, width: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('h:mm a').format(DateTime.now().toLocal()),
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
