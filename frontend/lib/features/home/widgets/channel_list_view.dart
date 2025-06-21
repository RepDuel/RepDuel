import 'package:flutter/material.dart';
import '../../../core/models/channel.dart';

class ChannelListView extends StatelessWidget {
  final List<Channel> channels;
  final ValueChanged<Channel> onChannelSelected;
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
      color: Colors.grey[850],
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          final isSelected = channel.id == selectedChannel?.id;

          return ListTile(
            title: Text(
              '# ${channel.name}',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () => onChannelSelected(channel),
            selected: isSelected,
            selectedTileColor: Colors.grey[700],
            dense: true,
          );
        },
      ),
    );
  }
}
