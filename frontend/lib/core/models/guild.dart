// lib/core/models/guild.dart

import 'channel.dart';

class Guild {
  final String id;
  final String name;
  final String? iconUrl;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Channel>? channels;

  Guild({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.channels,
  });

  factory Guild.fromJson(Map<String, dynamic> json) {
    return Guild(
      id: json['id'],
      name: json['name'],
      iconUrl: json['icon_url'],
      ownerId: json['owner_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      channels: json['channels'] != null
          ? List<Channel>.from(
              json['channels'].map((channel) => Channel.fromJson(channel)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_url': iconUrl,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'channels': channels?.map((channel) => channel.toJson()).toList(),
    };
  }
}
