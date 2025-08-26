// frontend/lib/features/profile/screens/settings_screen.dart

import '../../../core/config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../router/app_router.dart'; // Import this to get the key
import '../../../widgets/loading_spinner.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  BuildContext get _rootContext {
    // Helper to safely get the root navigator's context.
    final context = rootNavigatorKey.currentContext;
    assert(context != null, 'Root navigator context is not available');
    return context!;
  }

  Future<void> _changeProfilePicture(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked == null) return;
    
    final bytes = await picked.readAsBytes();
    final filename = picked.name;
    final mimeType = picked.mimeType ?? 'image/jpeg';

    final authNotifier = ref.read(authProvider.notifier);
    final ok = await authNotifier.updateProfilePictureFromBytes(bytes, filename, mimeType);

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
    final displayedWeight = user.weight != null ? (user.weight! * user.weightMultiplier).toStringAsFixed(1) : '';
    final controller = TextEditingController(text: displayedWeight);

    final result = await showDialog<String>(
      context: _rootContext, // Use the root context
      builder: (dialogContext) => AlertDialog(
        title: Text("Edit Weight ($unitLabel)"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text("Save")),
        ],
      ),
    );

    if (result != null) {
      final input = double.tryParse(result);
      if (input != null) {
        final storedWeight = input / user.weightMultiplier;
        await ref.read(authProvider.notifier).updateUser(weight: storedWeight);
      }
    }
  }

  Future<void> _editGender(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final result = await showDialog<String>(
      context: _rootContext, // Use the root context
      builder: (dialogContext) => AlertDialog(
        title: const Text("Select Gender"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Male', 'Female'].map((option) {
            return ListTile(
              title: Text(option, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, option),
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
      context: _rootContext, // Use the root context
      builder: (dialogContext) => AlertDialog(
        title: const Text("Select Weight Unit"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Kilograms', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(dialogContext, 'kg')),
            ListTile(title: const Text('Pounds', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(dialogContext, 'lbs')),
          ],
        ),
      ),
    );

    if (result != null && result != (isKg ? 'kg' : 'lbs')) {
      final newMultiplier = result == 'kg' ? 1.0 : 2.20462;
      await ref.read(authProvider.notifier).updateUser(weightMultiplier: newMultiplier);
    }
  }

  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: _rootContext, // Use the root context
      builder: (dialogContext) => AlertDialog(
        title: const Text("Reset Progress"),
        content: const Text("Are you sure you want to delete all your scores? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text("Confirm")),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await http.delete(
      Uri.parse('${Env.baseUrl}/api/v1/scores/user/${user.id}'),
      headers: {
        'Authorization': 'Bearer ${ref.read(authProvider).token}',
        'Content-Type': 'application/json',
      },
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.statusCode == 204 ? 'Progress reset successfully.' : 'Failed to reset progress.'),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: _rootContext, // Use the root context
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
        content: const Text("Are you absolutely sure? All data will be permanently erased."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete Forever")),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = ref.read(authProvider).token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication error. Please log in again.')));
      return;
    }
    
    final response = await http.delete(
      Uri.parse('${Env.baseUrl}/api/v1/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (!context.mounted) return;

    if (response.statusCode == 204) {
      await ref.read(authProvider.notifier).logout();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete account. Please try again.')));
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: _rootContext, // Use the root context
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('You will be signed out of your account. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log out')),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
  }

  bool _isValidImageUrl(String? url) {
    return url != null && url.isNotEmpty && (url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.webp'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: LoadingSpinner()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ... The rest of your ListView remains unchanged
          GestureDetector(
            onTap: () => _changeProfilePicture(context, ref),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey[700],
                  backgroundImage: _isValidImageUrl(user.avatarUrl) ? NetworkImage(user.avatarUrl!) as ImageProvider<Object> : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider<Object>,
                ),
                const SizedBox(height: 8),
                const Text('Tap to change picture', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ListTile(
            title: const Text('Gender', style: TextStyle(color: Colors.white)),
            subtitle: Text(user.gender ?? "Unknown", style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.edit, color: Colors.white),
            onTap: () => _editGender(context, ref),
          ),
          const Divider(color: Colors.grey),
          ListTile(
            title: const Text('Weight', style: TextStyle(color: Colors.white)),
            subtitle: Text(user.weight != null ? (user.weight! * user.weightMultiplier).toStringAsFixed(1) + (user.weightMultiplier == 1.0 ? " kg" : " lbs") : "N/A", style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.edit, color: Colors.white),
            onTap: () => _editWeight(context, ref),
          ),
          const Divider(color: Colors.grey),
          ListTile(
            title: const Text('Weight Unit (kg/lbs)', style: TextStyle(color: Colors.white)),
            subtitle: Text(user.weightMultiplier == 1.0 ? "kg" : "lbs", style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.edit, color: Colors.white),
            onTap: () => _editWeightUnit(context, ref),
          ),
          const Divider(color: Colors.grey),
          ListTile(
            title: const Text('Reset Progress', style: TextStyle(color: Colors.red)),
            trailing: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onTap: () => _resetProgress(context, ref),
          ),
          const Divider(color: Colors.grey),
          ListTile(
            title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('This action is permanent.', style: TextStyle(color: Colors.redAccent)),
            trailing: const Icon(Icons.warning, color: Colors.red),
            onTap: () => _deleteAccount(context, ref),
          ),
          const Divider(color: Colors.grey),
          ListTile(
            title: const Text('Log out', style: TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.logout, color: Colors.white),
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }
}