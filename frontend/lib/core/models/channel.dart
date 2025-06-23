// frontend/lib/core/models/channel.dart

import 'package:frontend/core/models/message.dart';

class Channel {
  final String id;
  final String name;
  final String guildId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message>? messages;

  Channel({
    required this.id,
    required this.name,
    required this.guildId,
    required this.createdAt,
    required this.updatedAt,
    this.messages,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      name: json['name'],
      guildId: json['guild_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      messages: json['messages'] != null
          ? List<Message>.from(
              json['messages'].map((msg) => Message.fromJson(msg)),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'guild_id': guildId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (messages != null)
        'messages': messages!.map((msg) => msg.toJson()).toList(),
    };
  }
}
