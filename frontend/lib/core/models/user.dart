// frontend/lib/core/models/user.dart

class User {
  final String id;
  final String username;
  final String email;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;
  final String? displayName;
  final double? weight;
  final String? gender;
  final double weightMultiplier;
  final String subscriptionLevel;
  final double energy;
  final String? rank;
  final String preferredUnit; // "kg" or "lbs"

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.displayName,
    this.weight,
    this.gender,
    this.weightMultiplier = 1.0,
    this.subscriptionLevel = 'free',
    this.energy = 0.0,
    this.rank,
    this.preferredUnit = 'kg',
  });

  User copyWith({
    String? id,
    String? username,
    String? email,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? avatarUrl,
    String? displayName,
    double? weight,
    String? gender,
    double? weightMultiplier,
    String? subscriptionLevel,
    double? energy,
    String? rank,
    String? preferredUnit,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      weightMultiplier: weightMultiplier ?? this.weightMultiplier,
      subscriptionLevel: subscriptionLevel ?? this.subscriptionLevel,
      energy: energy ?? this.energy,
      rank: rank ?? this.rank,
      preferredUnit: preferredUnit ?? this.preferredUnit,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final gender = json['gender'] as String?;
    final rawAvatar = (json['avatar_url'] as String?)?.trim();
    final computedAvatar = rawAvatar != null && rawAvatar.isNotEmpty
        ? rawAvatar
        : _defaultAvatarForGender(id, gender);

    return User(
      id: id,
      username: json['username'] as String,
      email: json['email'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      avatarUrl: computedAvatar,
      displayName: json['display_name'] as String?,
      weight:
          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      gender: gender,
      weightMultiplier: (json['weight_multiplier'] as num?)?.toDouble() ?? 1.0,
      subscriptionLevel: json['subscription_level'] as String? ?? 'free',
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      rank: json['rank'] as String?,
      preferredUnit: json['preferred_unit'] as String? ??
          ((json['weight_multiplier'] != null &&
                  (json['weight_multiplier'] as num).toDouble() > 1.5)
              ? 'lbs'
              : 'kg'),
    );
  }

  static String _defaultAvatarForGender(String id, String? gender) {
    final normalized = gender?.trim().toLowerCase();

    String pickFemaleVariant() {
      final hash = id.hashCode & 0x7fffffff;
      return hash % 3 == 0
          ? 'assets/images/rare_female.png'
          : 'assets/images/default_female.png';
    }

    if (normalized == 'male' || normalized == 'm') {
      return 'assets/images/default_male.png';
    }

    if (normalized == 'female' || normalized == 'f') {
      return pickFemaleVariant();
    }

    if (normalized == 'non-binary' ||
        normalized == 'nonbinary' ||
        normalized == 'nb') {
      return 'assets/images/default_nonbinary.png';
    }

    if (normalized == 'woman') {
      return pickFemaleVariant();
    }

    if (normalized == 'man') {
      return 'assets/images/default_male.png';
    }

    return 'assets/images/default_nonbinary.png';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'avatar_url': avatarUrl,
      'display_name': displayName,
      'weight': weight,
      'gender': gender,
      'weight_multiplier': weightMultiplier,
      'subscription_level': subscriptionLevel,
      'energy': energy,
      'rank': rank,
      'preferred_unit': preferredUnit,
    };
  }
}
