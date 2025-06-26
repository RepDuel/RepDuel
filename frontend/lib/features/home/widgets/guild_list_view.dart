import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/guild.dart';
import '../../../core/providers/api_providers.dart';

class GuildListView extends ConsumerWidget {
  final Guild? selectedGuild;
  final Function(Guild) onGuildSelected;

  const GuildListView({
    super.key,
    required this.onGuildSelected,
    this.selectedGuild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guildsAsyncValue = ref.watch(myGuildsProvider);

    return Container(
      width: 72,
      color: Theme.of(context).colorScheme.surface,
      child: guildsAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => const Center(child: Icon(Icons.error)),
        data: (guilds) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            itemCount: guilds.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final guild = guilds[index];
              return GestureDetector(
                onTap: () => onGuildSelected(guild),
                child: GuildIcon(
                  guild: guild,
                  isSelected: selectedGuild?.id == guild.id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GuildIcon extends StatelessWidget {
  final Guild guild;
  final bool isSelected;

  const GuildIcon({
    super.key,
    required this.guild,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: guild.name,
      child: CircleAvatar(
        radius: isSelected ? 28 : 24,
        backgroundColor: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          guild.name.isNotEmpty ? guild.name[0].toUpperCase() : 'G',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}