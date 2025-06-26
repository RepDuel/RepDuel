import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/channel.dart';
import '../../../core/models/guild.dart';
import '../../chat/screens/channel_screen.dart'; // Keep for now
import '../widgets/channel_list_view.dart';
import '../widgets/guild_list_view.dart';

// Provider to manage the currently selected guild
final selectedGuildProvider = StateProvider<Guild?>((ref) => null);

// Provider to manage the currently selected channel
final selectedChannelProvider = StateProvider<Channel?>((ref) => null);

// Convert HomeScreen to a ConsumerWidget
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the state providers for selected guild and channel
    final selectedGuild = ref.watch(selectedGuildProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);

    // This is a placeholder for channel data, which will be fetched later
    final List<Channel> channels = []; // Empty for now

    return Scaffold(
      body: Row(
        children: [
          GuildListView(
            selectedGuild: selectedGuild,
            onGuildSelected: (guild) {
              // When a guild is selected, update the provider's state
              ref.read(selectedGuildProvider.notifier).state = guild;
              // In the future, this is where you would trigger fetching channels for this guild
              ref.read(selectedChannelProvider.notifier).state = null; // Reset selected channel
            },
          ),
          if (selectedGuild != null)
            ChannelListView(
              channels: channels, // Pass the (currently empty) channel list
              selectedChannel: selectedChannel,
              onChannelSelected: (channel) {
                ref.read(selectedChannelProvider.notifier).state = channel;
              },
            ),
          Expanded(
            child: selectedChannel != null
                // If a channel is selected, show the ChannelScreen
                ? ChannelScreen(channelId: selectedChannel.id)
                // Otherwise, show a placeholder
                : const Center(child: Text('Select a channel to start chatting')),
          ),
        ],
      ),
    );
  }
}