// frontend/lib/features/profile/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/auth_provider.dart';

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

    final controller =
        TextEditingController(text: user.weight?.toString() ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Weight (kg)"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white),
        contentTextStyle: const TextStyle(color: Colors.white),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter weight in kg",
            hintStyle: TextStyle(color: Colors.grey),
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
      final weight = double.tryParse(result);
      if (weight != null) {
        await ref.read(authProvider.notifier).updateUser(weight: weight);
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
                  title: const Text('Weight (kg)',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text(user.weight?.toStringAsFixed(1) ?? "N/A",
                      style: const TextStyle(color: Colors.grey)),
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
              ],
            ),
    );
  }
}
