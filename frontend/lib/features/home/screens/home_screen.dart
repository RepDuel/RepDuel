// lib/features/home/screens/home_screen.dart

import 'package:flutter/material.dart';

import '../../../core/models/channel.dart';
import '../../../core/models/guild.dart';
import '../../chat/screens/channel_screen.dart';
import '../widgets/channel_list_view.dart';
import '../widgets/guild_list_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Guild> guilds = [];
  List<Channel> channels = [];
  Guild? selectedGuild;
  Channel? selectedChannel;

  @override
  void initState() {
    super.initState();
    _loadMockData();
  }

  void _loadMockData() {
    final now = DateTime.now();

    guilds = [
      Guild(
        id: '1',
        name: 'Guild One',
        iconUrl: null,
        ownerId: 'user-123',
        createdAt: now,
        updatedAt: now,
      ),
      Guild(
        id: '2',
        name: 'Guild Two',
        iconUrl: null,
        ownerId: 'user-123',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    _onGuildSelected(guilds.first);
  }

  void _onGuildSelected(Guild guild) {
    final now = DateTime.now();

    setState(() {
      selectedGuild = guild;
      selectedChannel = null;
      channels = [
        Channel(
          id: 'a962e33f-51c6-4bc7-89b0-1587dcd82213',
          name: 'general',
          guildId: guild.id,
          createdAt: now,
          updatedAt: now,
        ),
        Channel(
          id: 'b372f44a-3abc-4e27-96db-7a1a85b0c7f3',
          name: 'random',
          guildId: guild.id,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      selectedChannel = channels.first;
    });
  }

  void _onChannelSelected(Channel channel) {
    setState(() {
      selectedChannel = channel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          GuildListView(
            guilds: guilds,
            onGuildSelected: _onGuildSelected,
            selectedGuild: selectedGuild,
          ),
          ChannelListView(
            channels: channels,
            onChannelSelected: _onChannelSelected,
            selectedChannel: selectedChannel,
          ),
          Expanded(
            child: selectedChannel == null
                ? const Center(child: Text('Select a channel'))
                : ChannelScreen(channelId: selectedChannel!.id),
          ),
        ],
      ),
    );
  }
}
