// frontend/lib/features/profile/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/themes/app_themes.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changeProfilePicture(
      BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    // --- THIS IS THE FIX ---
    // We provide a fallback value for picked.mimeType using the ?? operator.
    // If mimeType is null, it will safely default to 'image/jpeg'.
    final ok = await ref.read(authProvider.notifier).updateProfilePictureFromBytes(
          bytes,
          picked.name,
          picked.mimeType ?? 'image/jpeg',
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Profile picture updated!' : 'Upload failed.'),
        ),
      );
    }
  }

  Future<void> _editWeight(
      BuildContext context, WidgetRef ref, AppTheme theme) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final isKg = user.weightMultiplier == 1.0;
    final unitLabel = isKg ? 'kg' : 'lbs';
    final displayedWeight = user.weight != null
        ? (user.weight! * user.weightMultiplier).toStringAsFixed(1)
        : '';
    final controller = TextEditingController(text: displayedWeight);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Edit Weight ($unitLabel)"),
        backgroundColor: theme.card,
        titleTextStyle: TextStyle(color: theme.primary),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: theme.primary),
          decoration: InputDecoration(
            hintText: "Enter weight in $unitLabel",
            hintStyle: TextStyle(color: theme.primary.withOpacity(0.5)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: theme.accent))),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text("Save", style: TextStyle(color: theme.accent))),
        ],
      ),
    );

    if (result != null) {
      final input = double.tryParse(result);
      if (input != null) {
        await ref
            .read(authProvider.notifier)
            .updateUser(weight: input / user.weightMultiplier);
      }
    }
  }

  Future<void> _editGender(
      BuildContext context, WidgetRef ref, AppTheme theme) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Gender"),
        backgroundColor: theme.card,
        titleTextStyle: TextStyle(color: theme.primary),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Male', 'Female'].map((option) {
            return ListTile(
              title: Text(option, style: TextStyle(color: theme.primary)),
              onTap: () => Navigator.pop(context, option),
            );
          }).toList(),
        ),
      ),
    );

    if (result != null && result != user.gender) {
      await ref.read(authProvider.notifier).updateUser(gender: result);
    }
  }

  Future<void> _editWeightUnit(
      BuildContext context, WidgetRef ref, AppTheme theme) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Weight Unit"),
        backgroundColor: theme.card,
        titleTextStyle: TextStyle(color: theme.primary),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                title: Text('Kilograms', style: TextStyle(color: theme.primary)),
                onTap: () => Navigator.pop(context, 'kg')),
            ListTile(
                title: Text('Pounds', style: TextStyle(color: theme.primary)),
                onTap: () => Navigator.pop(context, 'lbs')),
          ],
        ),
      ),
    );

    if (result != null) {
      await ref
          .read(authProvider.notifier)
          .updateUser(weightMultiplier: result == 'kg' ? 1.0 : 2.20462);
    }
  }

  Future<void> _logout(
      BuildContext context, WidgetRef ref, AppTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.card,
        title: Text('Log out', style: TextStyle(color: theme.primary)),
        content: Text(
            'You will be signed out of your account on this device. Continue?',
            style: TextStyle(color: theme.primary.withOpacity(0.8))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: theme.accent))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Log out', style: TextStyle(color: theme.accent))),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasAbsolutePath;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = ref.watch(themeProvider);
    final dividerColor = theme.primary.withOpacity(0.2);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: theme.primary)),
        backgroundColor: theme.background,
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: user == null
          ? Center(
              child:
                  Text('User not found.', style: TextStyle(color: theme.primary)))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                GestureDetector(
                  onTap: () => _changeProfilePicture(context, ref),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: theme.card,
                        backgroundImage: _isValidImageUrl(user.avatarUrl)
                            ? NetworkImage(user.avatarUrl!)
                            : const AssetImage(
                                    'assets/images/profile_placeholder.png')
                                as ImageProvider,
                      ),
                      const SizedBox(height: 8),
                      Text('Tap to change picture',
                          style:
                              TextStyle(color: theme.primary.withOpacity(0.5))),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                _SettingsSectionHeader(title: 'ACCOUNT', theme: theme),
                _SettingsTile(
                  title: 'Gender',
                  subtitle: user.gender ?? "Not Set",
                  onTap: () => _editGender(context, ref, theme),
                  theme: theme,
                ),
                Divider(color: dividerColor),
                _SettingsTile(
                  title: 'Weight',
                  subtitle: user.weight != null
                      ? "${(user.weight! * user.weightMultiplier).toStringAsFixed(1)} ${user.weightMultiplier == 1.0 ? "kg" : "lbs"}"
                      : "Not Set",
                  onTap: () => _editWeight(context, ref, theme),
                  theme: theme,
                ),
                Divider(color: dividerColor),
                _SettingsTile(
                  title: 'Weight Unit',
                  subtitle: user.weightMultiplier == 1.0 ? "kg" : "lbs",
                  onTap: () => _editWeightUnit(context, ref, theme),
                  theme: theme,
                ),
                const SizedBox(height: 24),
                _SettingsSectionHeader(title: 'APPEARANCE', theme: theme),
                _SettingsTile(
                  title: 'App Theme',
                  subtitle: theme.name,
                  onTap: () => context.push('/theme-selector'),
                  theme: theme,
                ),
                const SizedBox(height: 24),
                _SettingsSectionHeader(title: 'SESSION', theme: theme),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Log out', style: TextStyle(color: theme.primary)),
                  trailing: Icon(Icons.logout, color: theme.primary),
                  onTap: () => _logout(context, ref, theme),
                ),
                Divider(color: dividerColor),
              ],
            ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  final AppTheme theme;
  const _SettingsSectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
            color: theme.primary.withOpacity(0.6),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final AppTheme theme;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: theme.primary)),
      subtitle: Text(subtitle,
          style: TextStyle(color: theme.primary.withOpacity(0.6))),
      trailing: Icon(Icons.arrow_forward_ios, color: theme.primary, size: 16),
      onTap: onTap,
    );
  }
}