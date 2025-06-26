import 'package:flutter/material.dart';
import '../../../core/models/channel.dart';

class ChannelListView extends StatelessWidget {
  final List<Channel> channels;
  final Function(Channel) onChannelSelected;
  final Channel? selectedChannel;

  const ChannelListView({
    super.key,
    required this.channels,
    required this.onChannelSelected,
    this.selectedChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Theme.of(context).canvasColor,
      child: ListView.builder(
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          return ListTile(
            title: Text('# ${channel.name}'),
            onTap: () => onChannelSelected(channel),
            selected: selectedChannel?.id == channel.id,
          );
        },
      ),
    );
  }
}