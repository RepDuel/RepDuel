// frontend/lib/core/models/user_profile.dart

import 'package:flutter/material.dart';
import 'role.dart';

class UserProfile {
  final String id;
  final String username;
  final String? avatarUrl;
  final List<Role> roles;

  UserProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.roles,
  });

  Role get highestRole {
    return roles.isNotEmpty
        ? roles.first
        : Role(name: 'Unranked', color: const Color(0xFFFFFFFF), iconPath: '');
  }
}
