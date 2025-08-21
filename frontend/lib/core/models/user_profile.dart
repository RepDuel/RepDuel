import 'package:flutter/material.dart';
import 'role.dart';
import '../../theme/app_theme.dart';

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
        : Role(name: 'Unranked', color: AppTheme.rankColors['Unranked']!, iconPath: '');
  }
}
