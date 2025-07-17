// frontend/lib/core/models/message.dart

class Message {
  final String id;
  final String content;
  final String authorId;
  final String channelId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.content,
    required this.authorId,
    required this.channelId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Optional convenience getter (used in ChatBubble or elsewhere)
  /// Returns a user-friendly sender label
  String get sender => authorId;

  /// Deserialize from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      authorId: json['authorId'] ?? '',
      channelId: json['channelId'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'author_id': authorId,
        'channel_id': channelId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
