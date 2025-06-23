import 'package:flutter/material.dart';
import '../../../core/models/guild.dart';

class GuildListView extends StatelessWidget {
  final List<Guild> guilds;
  final ValueChanged<Guild> onGuildSelected;
  final Guild? selectedGuild;

  const GuildListView({
    super.key,
    required this.guilds,
    required this.onGuildSelected,
    this.selectedGuild,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: Colors.grey[900],
      child: ListView.builder(
        itemCount: guilds.length,
        itemBuilder: (context, index) {
          final guild = guilds[index];
          final isSelected = guild.id == selectedGuild?.id;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: () => onGuildSelected(guild),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: isSelected ? Colors.blueAccent : Colors.grey[800],
                backgroundImage: NetworkImage(guild.iconUrl ?? 'https://upload.wikimedia.org/wikipedia/commons/a/ac/Default_pfp.jpg'),
                child: guild.iconUrl == null
                    ? Text(
                        guild.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
