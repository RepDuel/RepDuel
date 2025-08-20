// frontend/lib/core/models/guild.dart

class Guild {
  final String id;
  final String name;
  final String? iconUrl;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Guild({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt
  });

  factory Guild.fromJson(Map<String, dynamic> json) {
    return Guild(
      id: json['id'],
      name: json['name'],
      iconUrl: json['icon_url'],
      ownerId: json['owner_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at'])
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon_url': iconUrl,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String()
    };
  }
}
