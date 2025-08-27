// frontend/lib/features/profile/screens/settings_screen.dart

import '../../../core/config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart'; // Import auth provider
import '../../../core/services/secure_storage_service.dart'; // Might not be directly needed here anymore
import '../../../router/app_router.dart'; // Import this to get the key for root context
import '../../../widgets/loading_spinner.dart';
import '../../../core/providers/iap_provider.dart'; // Import IAP provider for restore purchases

class SettingsScreen extends ConsumerWidget { // Changed to ConsumerWidget for ref access
  const SettingsScreen({super.key});

  // Helper to safely get the root navigator's context for dialogs.
  BuildContext get _rootContext {
    final context = rootNavigatorKey.currentContext;
    assert(context != null, 'Root navigator context is not available');
    return context!;
  }

  /// Handles picking and uploading a new profile picture.
  Future<void> _changeProfilePicture(WidgetRef ref) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile == null) return; // User cancelled

    final bytes = await pickedFile.readAsBytes();
    final filename = pickedFile.name;
    final mimeType = pickedFile.mimeType ?? 'image/jpeg';

    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.updateProfilePictureFromBytes(bytes, filename, mimeType);

    // Show feedback to the user
    if (!navigatorKey.currentContext!.mounted) return; // Check context mounted status if using navigatorKey
    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar( // Use navigatorKey context
      SnackBar(
        content: Text(success ? 'Profile picture updated successfully!' : 'Failed to update profile picture. Please try again.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  /// Opens a dialog to edit the user's weight.
  Future<void> _editWeight(WidgetRef ref) async {
    // Safely access current user state and token
    final currentUserState = ref.read(authProvider).valueOrNull;
    final user = currentUserState?.user; // Non-null assertion safe after checks
    final token = currentUserState?.token;

    if (user == null || token == null) {
      // If user or token is null, cannot proceed. This should ideally be handled by routing guards.
      // Show an error or return if auth state is not ready.
      return; 
    }

    final isKg = user.weightMultiplier == 1.0;
    final unitLabel = isKg ? 'kg' : 'lbs';
    final displayedWeight = user.weight != null ? (user.weight! * user.weightMultiplier).toStringAsFixed(1) : '';
    final controller = TextEditingController(text: displayedWeight);

    final String? newWeightString = await showDialog<String>(
      context: _rootContext,
      builder: (dialogContext) => AlertDialog(
        title: Text("Edit Weight ($unitLabel)"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Enter weight in $unitLabel",
            hintStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final input = double.tryParse(controller.text);
              if (input == null || input <= 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid positive number.'), backgroundColor: Colors.red),
                );
              } else {
                Navigator.pop(dialogContext, controller.text);
              }
            }, 
            child: const Text("Save", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );

    if (newWeightString != null) {
      final newWeightInUserUnits = double.tryParse(newWeightString);
      if (newWeightInUserUnits != null && newWeightInUserUnits > 0) {
        final storedWeight = newWeightInUserUnits / user.weightMultiplier;
        final success = await ref.read(authProvider.notifier).updateUser(weight: storedWeight);
        if (!mounted) return; // Check mounted status after async call
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Weight updated!' : 'Failed to update weight.'), backgroundColor: success ? Colors.green : Colors.red),
        );
      } else {
        if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid input.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Opens a dialog to edit the user's gender.
  Future<void> _editGender(WidgetRef ref) async {
    // Safely access current user state
    final currentUserState = ref.read(authProvider).valueOrNull;
    final user = currentUserState?.user; 
    if (user == null) return;

    final String? newGender = await showDialog<String>(
      context: _rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Select Gender"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Male', 'Female', 'Other', 'Prefer not to say'].map((option) { // Added more options
            return ListTile(
              title: Text(option, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, option),
            );
          }).toList(),
        ),
      ),
    );

    if (newGender != null && newGender != user.gender) {
      final success = await ref.read(authProvider.notifier).updateUser(gender: newGender);
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Gender updated!' : 'Failed to update gender.'), backgroundColor: success ? Colors.green : Colors.red),
      );
    }
  }

  /// Opens a dialog to switch between kg and lbs for weight.
  Future<void> _editWeightUnit(WidgetRef ref) async {
    // Safely access current user state
    final currentUserState = ref.read(authProvider).valueOrNull;
    final user = currentUserState?.user;
    if (user == null) return;

    final isKg = user.weightMultiplier == 1.0;
    final currentUnit = isKg ? 'kg' : 'lbs';

    final String? newUnit = await showDialog<String>(
      context: _rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Select Weight Unit"),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Kilograms (kg)', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, 'kg'),
              selected: isKg,
            ),
            ListTile(
              title: const Text('Pounds (lbs)', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, 'lbs'),
              selected: !isKg,
            ),
          ],
        ),
      ),
    );

    if (newUnit != null && newUnit != currentUnit) {
      final newMultiplier = (newUnit == 'kg' ? 1.0 : 2.20462);
      final success = await ref.read(authProvider.notifier).updateUser(weightMultiplier: newMultiplier);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Weight unit updated!' : 'Failed to update weight unit.'), backgroundColor: success ? Colors.green : Colors.red),
      );
    }
  }

  /// Confirms and then calls the API to reset user's progress data.
  Future<void> _resetProgress(WidgetRef ref) async {
    // Safely access user and token
    final currentUserState = ref.read(authProvider).valueOrNull;
    final user = currentUserState?.user;
    final token = currentUserState?.token;

    if (user == null || token == null) {
      _showErrorSnackbar('Cannot reset progress. Authentication is missing.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: _rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Reset Progress", style: TextStyle(color: Colors.red)),
        content: const Text("Are you sure you want to delete all your recorded scores and history? This action cannot be undone."),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), 
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Confirm Reset"),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // User cancelled

    try {
      final response = await http.delete(
        Uri.parse('${Env.baseUrl}/api/v1/scores/user/${user.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 204) { 
        _showSuccessSnackbar('Your progress has been reset successfully.');
        // Optionally, refresh user data if it includes score-dependent fields,
        // or re-fetch relevant data providers.
        ref.read(authProvider.notifier).refreshUserData(); 
      } else {
        _showErrorSnackbar('Failed to reset progress. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackbar('An error occurred while resetting progress: $e');
    }
  }

  /// Confirms and then calls the API to delete the user's account.
  Future<void> _deleteAccount(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: _rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text("Are you absolutely sure you want to delete your account? All your data, including workout history and scores, will be permanently erased and cannot be recovered."),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), 
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = ref.read(authProvider).valueOrNull?.token;
    if (token == null) {
      _showErrorSnackbar('Authentication error. Please log in again.');
      return;
    }
    
    try {
      final response = await http.delete(
        Uri.parse('${Env.baseUrl}/api/v1/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 204) {
        _showSuccessSnackbar('Account deleted successfully. You have been logged out.');
        await ref.read(authProvider.notifier).logout();
      } else {
        _showErrorSnackbar('Failed to delete account. Please try again.');
      }
    } catch (e) {
      _showErrorSnackbar('An error occurred while deleting your account: $e');
    }
  }

  /// Handles the user logging out.
  Future<void> _logout(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: _rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out of your account?'),
        backgroundColor: Colors.grey[900],
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), 
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true), 
            child: const Text('Log out', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Successfully signed out.'), backgroundColor: Colors.green),
    );
  }

  /// Restores previous purchases using the subscription provider.
  Future<void> _restorePurchases(WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Restoring purchases..."), backgroundColor: Colors.blue),
    );
    try {
      await ref.read(subscriptionProvider.notifier).restorePurchases();
      if (mounted) {
        // After restoring, it's good practice to also refresh user data from backend,
        // in case subscription tier is updated there.
        ref.read(authProvider.notifier).refreshUserData(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Purchases restored successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar("Failed to restore purchases: ${e.toString()}");
      }
    }
  }

  /// Helper to show a snackbar with an error message.
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Helper to show a snackbar with a success message.
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Basic validation for image URLs.
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Corrected build method signature
    // Watch the authProvider, which returns AsyncValue<AuthState>.
    final authStateAsyncValue = ref.watch(authProvider);

    // Use .when() to handle loading, error, and data states from AsyncValue.
    return authStateAsyncValue.when(
      loading: () => const Scaffold( // Display loading spinner if auth state is loading
        backgroundColor: Colors.black,
        body: Center(child: LoadingSpinner()),
      ),
      error: (error, stackTrace) => Scaffold( // Display error message if auth fails to load
        backgroundColor: Colors.black,
        body: Center(child: Text('Error loading profile: $error', style: const TextStyle(color: Colors.red))),
      ),
      data: (authState) { // authState is the actual AuthState object here
        // Now, check if the user data within the AuthState is null.
        final user = authState.user; 

        // If user is null even after loading, it means the user is logged out.
        // The router should handle redirecting to login in this case.
        // For safety, we'll return a loading screen or empty screen here if the user is null,
        // allowing the router to take over.
        if (user == null) {
          // This case should ideally be handled by the router redirecting to login,
          // but as a fallback, we show a loading spinner.
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: LoadingSpinner()), 
          );
        }

        // --- User is logged in and available ---
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Picture Section
              GestureDetector(
                onTap: () => _changeProfilePicture(ref), // Pass ref directly
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey[700],
                      backgroundImage: _isValidImageUrl(user.avatarUrl)
                          ? NetworkImage(user.avatarUrl!) as ImageProvider<Object>
                          : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider<Object>,
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap to change picture', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Account Details Section
              ListTile(
                title: const Text('Username', style: TextStyle(color: Colors.white)),
                subtitle: Text(user.username, style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.edit, color: Colors.grey, size: 18), // Indicate it's view-only here
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username editing is not yet supported.'), backgroundColor: Colors.blue),
                  );
                },
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text('Gender', style: TextStyle(color: Colors.white)),
                subtitle: Text(user.gender ?? "Not specified", style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.edit, color: Colors.white),
                onTap: () => _editGender(ref), // Pass ref
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text('Weight', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  user.weight != null
                      ? "${(user.weight! * user.weightMultiplier).toStringAsFixed(1)} ${user.weightMultiplier == 1.0 ? "kg" : "lbs"}"
                      : "Not specified",
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: const Icon(Icons.edit, color: Colors.white),
                onTap: () => _editWeight(ref), // Pass ref
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text('Weight Unit', style: TextStyle(color: Colors.white)),
                subtitle: Text(user.weightMultiplier == 1.0 ? "Kilograms (kg)" : "Pounds (lbs)", style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.edit, color: Colors.white),
                onTap: () => _editWeightUnit(ref), // Pass ref
              ),
              const Divider(color: Colors.grey),

              // Subscription Section
              ListTile(
                title: const Text('Restore Purchases', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Re-sync your subscription status', style: TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.restore, color: Colors.white),
                onTap: () => _restorePurchases(ref), // Pass ref
              ),
              const Divider(color: Colors.grey),

              // Danger Zone Section
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Danger Zone',
                  style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Reset Progress', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Delete all your workout scores', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                trailing: const Icon(Icons.delete_forever, color: Colors.redAccent),
                onTap: () => _resetProgress(ref), // Pass ref
              ),
              const Divider(color: Colors.grey),

              ListTile(
                title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('Permanently erase your account and data', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                trailing: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                onTap: () => _deleteAccount(ref), // Pass ref
              ),
              const Divider(color: Colors.grey),

              // Logout Button
              ListTile(
                title: const Text('Log out', style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.logout, color: Colors.white),
                onTap: () => _logout(ref), // Pass ref
              ),
            ],
          ),
        );
      },
    );
  }
}