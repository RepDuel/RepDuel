// frontend/lib/features/profile/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/iap_provider.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../core/models/user.dart';

// 1. Converted to ConsumerStatefulWidget for managing state and async operations.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

// 2. The State class now holds all logic. `mounted` and `context` are available here.
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // --- Helper Methods for UI ---

  /// Converts a value to the user's selected display unit (lbs or kg).
  double _toDisplayUnit(User user, double value) {
    return value * (user.weightMultiplier);
  }

  /// Returns the string label for the current unit ('kg' or 'lbs').
  String _unitLabel(User user) {
    return (user.weightMultiplier) == 1.0 ? 'kg' : 'lbs';
  }

  /// Generic snackbar for showing feedback (success or error).
  void _showFeedbackSnackbar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  /// Generic confirmation dialog.
  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title,
            style: TextStyle(color: isDestructive ? Colors.red : Colors.white)),
        content: Text(content),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
                foregroundColor: isDestructive ? Colors.red : Colors.amber),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // --- Feature Logic Methods ---

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final success = await ref
        .read(authProvider.notifier)
        .updateProfilePictureFromBytes(
            bytes, pickedFile.name, pickedFile.mimeType ?? 'image/jpeg');

    _showFeedbackSnackbar(
        success
            ? 'Profile picture updated!'
            : 'Failed to update profile picture.',
        isSuccess: success);
  }

  Future<void> _editWeight() async {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) {
      _showFeedbackSnackbar('Authentication required.', isSuccess: false);
      if (mounted) GoRouter.of(context).go('/login');
      return;
    }

    final unitLabel = _unitLabel(user);
    final displayedWeight = user.weight != null
        ? _toDisplayUnit(user, user.weight!).toStringAsFixed(1)
        : '';
    final controller = TextEditingController(text: displayedWeight);

    final newWeightString = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Edit Weight ($unitLabel)"),
        backgroundColor: Colors.grey[900],
        content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text("Save", style: TextStyle(color: Colors.amber))),
        ],
      ),
    );

    if (newWeightString != null) {
      final newWeightInUserUnits = double.tryParse(newWeightString);
      if (newWeightInUserUnits != null && newWeightInUserUnits > 0) {
        final storedWeight = newWeightInUserUnits /
            (user.weightMultiplier); // Convert back to base unit (KG)
        final success = await ref
            .read(authProvider.notifier)
            .updateUser(weight: storedWeight);
        _showFeedbackSnackbar(
            success ? 'Weight updated!' : 'Failed to update weight.',
            isSuccess: success);
      } else {
        _showFeedbackSnackbar('Invalid input.', isSuccess: false);
      }
    }
  }

  Future<void> _editGender() async {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) {
      _showFeedbackSnackbar('Authentication required.', isSuccess: false);
      if (mounted) GoRouter.of(context).go('/login');
      return;
    }

    final String? newGender = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Select Gender"),
        backgroundColor: Colors.grey[900],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              ['Male', 'Female', 'Other', 'Prefer not to say'].map((option) {
            return ListTile(
                title:
                    Text(option, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(dialogContext, option));
          }).toList(),
        ),
      ),
    );

    if (newGender != null && newGender != user.gender) {
      final success =
          await ref.read(authProvider.notifier).updateUser(gender: newGender);
      _showFeedbackSnackbar(
          success ? 'Gender updated!' : 'Failed to update gender.',
          isSuccess: success);
    }
  }

  Future<void> _editWeightUnit() async {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) {
      _showFeedbackSnackbar('Authentication required.', isSuccess: false);
      if (mounted) GoRouter.of(context).go('/login');
      return;
    }

    final isKg = (user.weightMultiplier) == 1.0;
    final String? newUnit = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Select Weight Unit"),
        backgroundColor: Colors.grey[900],
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                title: const Text('Kilograms (kg)'),
                onTap: () => Navigator.pop(dialogContext, 'kg'),
                selected: isKg),
            ListTile(
                title: const Text('Pounds (lbs)'),
                onTap: () => Navigator.pop(dialogContext, 'lbs'),
                selected: !isKg),
          ],
        ),
      ),
    );

    if (newUnit != null && (newUnit == 'kg') != isKg) {
      final newMultiplier = (newUnit == 'kg' ? 1.0 : 2.20462);
      final success = await ref
          .read(authProvider.notifier)
          .updateUser(weightMultiplier: newMultiplier);
      _showFeedbackSnackbar(
          success ? 'Weight unit updated!' : 'Failed to update weight unit.',
          isSuccess: success);
    }
  }

  Future<void> _restorePurchases() async {
    _showFeedbackSnackbar("Restoring purchases...",
        isSuccess: true); // Use a neutral color if possible, but green is ok.
    try {
      await ref.read(subscriptionProvider.notifier).restorePurchases();
      if (!mounted) return;
      ref.read(authProvider.notifier).refreshUserData();
      _showFeedbackSnackbar("Purchases restored successfully!",
          isSuccess: true);
    } catch (e) {
      _showFeedbackSnackbar("Failed to restore purchases: ${e.toString()}",
          isSuccess: false);
    }
  }

  Future<void> _resetProgress() async {
    final authState = ref.read(authProvider).valueOrNull;
    if (authState?.user?.id == null || authState?.token == null) {
      _showFeedbackSnackbar('Authentication required.', isSuccess: false);
      if (mounted) GoRouter.of(context).go('/login');
      return;
    }

    final confirmed = await _showConfirmationDialog(
        title: "Reset Progress",
        content: "This action cannot be undone.",
        confirmText: "Confirm Reset",
        isDestructive: true);
    if (confirmed != true) return;

    try {
      final response = await http.delete(
          Uri.parse('${Env.baseUrl}/api/v1/scores/user/${authState!.user!.id}'),
          headers: {'Authorization': 'Bearer ${authState.token}'});
      if (!mounted) return;
      if (response.statusCode == 204) {
        _showFeedbackSnackbar('Your progress has been reset.', isSuccess: true);
        ref.read(authProvider.notifier).refreshUserData();
      } else {
        _showFeedbackSnackbar(
            'Failed to reset progress. Code: ${response.statusCode}',
            isSuccess: false);
      }
    } catch (e) {
      _showFeedbackSnackbar('An error occurred: $e', isSuccess: false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmationDialog(
        title: "Delete Account",
        content: "This is permanent and cannot be undone.",
        confirmText: "Delete Forever",
        isDestructive: true);
    if (confirmed != true) return;

    final token = ref.read(authProvider).valueOrNull?.token;
    if (token == null) {
      _showFeedbackSnackbar('Authentication error. Please log in again.',
          isSuccess: false);
      if (mounted) GoRouter.of(context).go('/login');
      return;
    }

    try {
      final response = await http.delete(
          Uri.parse('${Env.baseUrl}/api/v1/users/me'),
          headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;
      if (response.statusCode == 204) {
        // The logout call will trigger navigation via the router listener
        await ref.read(authProvider.notifier).logout();
        _showFeedbackSnackbar('Account deleted successfully.', isSuccess: true);
      } else {
        _showFeedbackSnackbar('Failed to delete account. Please try again.',
            isSuccess: false);
      }
    } catch (e) {
      _showFeedbackSnackbar('An error occurred: $e', isSuccess: false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmationDialog(
        title: 'Log out',
        content: 'Are you sure you want to log out?',
        confirmText: 'Log out');
    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    _showFeedbackSnackbar('Successfully signed out.', isSuccess: true);
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasAbsolutePath;
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsyncValue = ref.watch(authProvider);

    return authStateAsyncValue.when(
      loading: () => const Scaffold(
          backgroundColor: Colors.black, body: Center(child: LoadingSpinner())),
      error: (error, _) => Scaffold(
          backgroundColor: Colors.black,
          body: Center(
              child: Text('Error: $error',
                  style: const TextStyle(color: Colors.red)))),
      data: (authState) {
        final user = authState.user;
        if (user == null) {
          return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: LoadingSpinner()));
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              title: const Text('Settings'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GestureDetector(
                onTap: _changeProfilePicture,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey[700],
                      backgroundImage: _isValidImageUrl(user.avatarUrl)
                          ? NetworkImage(user.avatarUrl!)
                          : const AssetImage(
                                  'assets/images/profile_placeholder.png')
                              as ImageProvider,
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap to change picture',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Username',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(user.username,
                    style: const TextStyle(color: Colors.grey)),
                trailing:
                    const Icon(Icons.edit_off, color: Colors.grey, size: 18),
                onTap: () => _showFeedbackSnackbar(
                    'Username cannot be changed.',
                    isSuccess: true),
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title:
                    const Text('Gender', style: TextStyle(color: Colors.white)),
                subtitle: Text(user.gender ?? "Not specified",
                    style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.edit, color: Colors.white),
                onTap: _editGender,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title:
                    const Text('Weight', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                    user.weight != null
                        ? "${_toDisplayUnit(user, user.weight!).toStringAsFixed(1)} ${_unitLabel(user)}"
                        : "Not specified",
                    style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.edit, color: Colors.white),
                onTap: _editWeight,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Weight Unit',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                    _unitLabel(user) == 'kg'
                        ? "Kilograms (kg)"
                        : "Pounds (lbs)",
                    style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.edit, color: Colors.white),
                onTap: _editWeightUnit,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Restore Purchases',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('Re-sync your subscription status',
                    style: TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.restore, color: Colors.white),
                onTap: _restorePurchases,
              ),
              const Divider(color: Colors.grey),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('Danger Zone',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              ListTile(
                title: const Text('Reset Progress',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text('Delete all your workout scores',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                trailing:
                    const Icon(Icons.delete_forever, color: Colors.redAccent),
                onTap: _resetProgress,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Delete Account',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('Permanently erase your account and data',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                trailing:
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                onTap: _deleteAccount,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Log out',
                    style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.logout, color: Colors.white),
                onTap: _logout,
              ),
            ],
          ),
        );
      },
    );
  }
}
