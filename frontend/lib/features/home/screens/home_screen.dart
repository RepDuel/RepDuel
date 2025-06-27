import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/channel.dart';
import '../../../core/models/guild.dart';
import '../../../core/providers/api_providers.dart';
import '../../chat/screens/channel_screen.dart';
import '../widgets/channel_list_view.dart';
import '../widgets/guild_list_view.dart';

// Providers to manage the currently selected guild and channel
final selectedGuildProvider = StateProvider<Guild?>((ref) => null);
final selectedChannelProvider = StateProvider<Channel?>((ref) => null);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGuild = ref.watch(selectedGuildProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);

    return Scaffold(
      body: Row(
        children: [
          GuildListView(
            selectedGuild: selectedGuild,
            onGuildSelected: (guild) {
              ref.read(selectedGuildProvider.notifier).state = guild;
              ref.read(selectedChannelProvider.notifier).state = null; // Deselect channel on new guild click
            },
          ),
          // Use a Builder to only try fetching channels if a guild is selected
          Builder(
            builder: (context) {
              if (selectedGuild == null) {
                // If no guild is selected, show an empty, styled container
                return Container(width: 240, color: Theme.of(context).canvasColor);
              }

              // If a guild IS selected, call the provider family with its ID
              final channelsAsyncValue = ref.watch(guildChannelsProvider(selectedGuild.id));

              // Use .when to handle loading/error states for the channel list
              return channelsAsyncValue.when(
                loading: () => const SizedBox(
                  width: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => SizedBox(
                  width: 240,
                  child: Center(child: Text('Error: $err')),
                ),
                data: (channels) => ChannelListView(
                  channels: channels,
                  selectedChannel: selectedChannel,
                  onChannelSelected: (channel) {
                    ref.read(selectedChannelProvider.notifier).state = channel;
                  },
                ),
              );
            },
          ),
          Expanded(
            child: selectedChannel != null
                ? ChannelScreen(channelId: selectedChannel.id)
                : const Center(child: Text('Select a channel to start chatting')),
          ),
        ],
      ),
    );
  }
}