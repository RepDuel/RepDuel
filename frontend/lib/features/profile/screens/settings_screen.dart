// frontend/lib/features/profile/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changeProfilePicture(
      BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    debugPrint('[📷] Starting image picker...');

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null) return;
    debugPrint('[📷] Picked image path: ${picked.path}');

    final bytes = await picked.readAsBytes();
    final filename = picked.name;
    final mimeType = picked.mimeType ?? 'image/jpeg';

    final authNotifier = ref.read(authProvider.notifier);
    final ok = await authNotifier.updateProfilePictureFromBytes(
        bytes, filename, mimeType);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile picture updated!' : 'Upload failed.'),
      ),
    );
  }

  Future<void> _editWeight(BuildContext context, WidgetRef ref) async {
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
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white),
        contentTextStyle: const TextStyle(color: Colors.white),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter weight in $unitLabel",
            hintStyle: const TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("Save")),
        ],
      ),
    );

    if (result != null) {
      final input = double.tryParse(result);
      if (input != null) {
        final storedWeight =
            input / user.weightMultiplier; // Convert back to kg
        await ref.read(authProvider.notifier).updateUser(weight: storedWeight);
      }
    }
  }

  Future<void> _editGender(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Gender"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white),
        contentTextStyle: const TextStyle(color: Colors.white),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Male', 'Female'].map((option) {
            return ListTile(
              title: Text(option, style: const TextStyle(color: Colors.white)),
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

  Future<void> _editWeightUnit(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final isKg = user.weightMultiplier == 1.0;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select Weight Unit"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white),
        contentTextStyle: const TextStyle(color: Colors.white),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                title: const Text('Kilograms',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, 'kg')),
            ListTile(
                title:
                    const Text('Pounds', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, 'lbs')),
          ],
        ),
      ),
    );

    if (result != null && result != (isKg ? 'kg' : 'lbs')) {
      final newMultiplier = result == 'kg' ? 1.0 : 2.20462;
      final success = await ref
          .read(authProvider.notifier)
          .updateUser(weightMultiplier: newMultiplier);
      if (!success) {
        debugPrint('Failed to update weight multiplier.');
      }
    }
  }

  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Progress"),
        content: const Text(
            "Are you sure you want to delete all your scores? This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await http.delete(
      Uri.parse('http://localhost:8000/api/v1/scores/user/${user.id}'),
      headers: {
        'Authorization': 'Bearer ${ref.read(authProvider).token}',
        'Content-Type': 'application/json',
      },
    );

    final success = response.statusCode == 204;

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Progress reset successfully.'
            : 'Failed to reset progress.'),
      ),
    );
  }

  /// Best-practice logout:
  /// - Confirm intent
  /// - Clear auth state via provider (this should also clear SecureStorage)
  /// - As a safety net, also clear SecureStorage token locally
  /// - Navigate to /login
  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text(
            'You will be signed out of your account on this device. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Preferred: use your auth provider's logout (clears state & tokens)
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      // Fallback: ensure local token is cleared even if provider doesn't expose logout
      try {
        await SecureStorageService().deleteToken();
      } catch (_) {}
      // Also try to reset provider user/token if your notifier exposes such methods
      // (left as comment since your notifier API may vary)
      // await ref.read(authProvider.notifier).reset();
    }

    if (!context.mounted) return;

    // Navigate to login (clears back stack)
    context.go('/login');

    // Optional: feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out')),
    );
  }

  bool _isValidImageUrl(String? url) {
    return url != null &&
        url.isNotEmpty &&
        (url.endsWith('.png') ||
            url.endsWith('.jpg') ||
            url.endsWith('.jpeg') ||
            url.endsWith('.webp'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(
              child: Text('User not found.',
                  style: TextStyle(color: Colors.white)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GestureDetector(
                  onTap: () => _changeProfilePicture(context, ref),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey[700],
                        backgroundImage: _isValidImageUrl(user.avatarUrl)
                            ? NetworkImage(user.avatarUrl!)
                                as ImageProvider<Object>
                            : const AssetImage(
                                    'assets/images/profile_placeholder.png')
                                as ImageProvider<Object>,
                      ),
                      const SizedBox(height: 8),
                      const Text('Tap to change picture',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Gender',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(user.gender ?? "Unknown",
                      style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.edit, color: Colors.white),
                  onTap: () => _editGender(context, ref),
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  title: const Text('Weight',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    user.weight != null
                        ? (user.weight! * user.weightMultiplier)
                                .toStringAsFixed(1) +
                            (user.weightMultiplier == 1.0 ? " kg" : " lbs")
                        : "N/A",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.white),
                  onTap: () => _editWeight(context, ref),
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  title: const Text('Weight Unit (kg/lbs)',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(user.weightMultiplier == 1.0 ? "kg" : "lbs",
                      style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.edit, color: Colors.white),
                  onTap: () => _editWeightUnit(context, ref),
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  title: const Text('Reset Progress',
                      style: TextStyle(color: Colors.red)),
                  trailing:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  onTap: () => _resetProgress(context, ref),
                ),
                const Divider(color: Colors.grey),

                // ---- Logout at the bottom ----
                ListTile(
                  title: const Text('Log out',
                      style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.logout, color: Colors.white),
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
    );
  }
}
