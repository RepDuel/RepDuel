// frontend/lib/core/models/social_user.dart

class SocialUserSummary {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isSelf;

  const SocialUserSummary({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isSelf,
  });

  String get primaryText {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    return '@$username';
  }

  String get secondaryText => '@$username';

  String? get resolvedAvatarUrl {
    final avatar = avatarUrl?.trim();
    if (avatar != null && avatar.isNotEmpty) {
      return avatar;
    }
    return null;
  }

  factory SocialUserSummary.fromJson(Map<String, dynamic> json) {
    return SocialUserSummary(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isFollowing: json['is_following'] as bool? ?? false,
      isFollowedBy: json['is_followed_by'] as bool? ?? false,
      isSelf: json['is_self'] as bool? ?? false,
    );
  }
}

class SocialSearchResults {
  final List<SocialUserSummary> items;
  final int total;
  final int? nextOffset;

  const SocialSearchResults({
    required this.items,
    required this.total,
    required this.nextOffset,
  });

  bool get hasMore => nextOffset != null;

  factory SocialSearchResults.empty() {
    return SocialSearchResults(
      items: const <SocialUserSummary>[],
      total: 0,
      nextOffset: null,
    );
  }

  factory SocialSearchResults.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    final parsedItems = itemsJson
        .whereType<Map<String, dynamic>>()
        .map(SocialUserSummary.fromJson)
        .toList(growable: false);

    return SocialSearchResults(
      items: parsedItems,
      total: (json['total'] as num?)?.toInt() ?? parsedItems.length,
      nextOffset: json['next_offset'] as int?,
    );
  }
}
