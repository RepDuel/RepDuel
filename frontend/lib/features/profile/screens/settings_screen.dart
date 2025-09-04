// frontend/lib/features/profile/screens/settings_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/iap_provider.dart';
import '../../../widgets/loading_spinner.dart';
import '../../../core/models/user.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isManagingSubscription = false;

  double _toDisplayUnit(User user, double value) =>
      value * user.weightMultiplier;
  String _unitLabel(User user) => user.weightMultiplier == 1.0 ? 'kg' : 'lbs';

  void _showFeedbackSnackbar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) {
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

  // ========== THIS IS THE CORRECT IMPLEMENTATION ==========
  Future<void> _manageSubscription() async {
    if (_isManagingSubscription) return;
    setState(() => _isManagingSubscription = true);

    try {
      if (kIsWeb) {
        // --- Web Flow (Stripe Portal) ---
        final client = ref.read(privateHttpClientProvider);
        final response =
            await client.dio.post('/payments/create-portal-session');
        final portalUrlString = response.data['portal_url'] as String?;
        if (portalUrlString == null || portalUrlString.isEmpty) {
          throw Exception("Could not retrieve subscription portal URL.");
        }
        final portalUrl = Uri.parse(portalUrlString);
        await launchUrl(portalUrl, webOnlyWindowName: '_self');
      } else {
        // --- Native iOS/Android Flow (RevenueCat Management URL) ---
        final customerInfo = await Purchases.getCustomerInfo();
        final managementURL = customerInfo.managementURL;

        if (managementURL == null) {
          throw Exception("Could not find subscription management URL.");
        }

        final uri = Uri.parse(managementURL);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw Exception("Could not launch URL: $managementURL");
        }
      }
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data?['detail'] ?? 'Failed to open subscription portal.';
      _showFeedbackSnackbar(errorMsg, isSuccess: false);
    } catch (e) {
      _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
          isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _isManagingSubscription = false);
      }
    }
  }
  // ========================================================

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
    if (user == null) return;
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
        final storedWeight = newWeightInUserUnits / user.weightMultiplier;
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
    if (user == null) return;
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
    if (user == null) return;
    final isKg = user.weightMultiplier == 1.0;
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
    _showFeedbackSnackbar("Restoring purchases...", isSuccess: true);
    try {
      await ref.read(subscriptionProvider.notifier).restorePurchases();
      if (!mounted) return;
      await ref.read(authProvider.notifier).refreshUserData();
      _showFeedbackSnackbar("Purchases restored successfully!",
          isSuccess: true);
    } catch (e) {
      _showFeedbackSnackbar("Failed to restore purchases: ${e.toString()}",
          isSuccess: false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmationDialog(
        title: 'Log out',
        content: 'Are you sure you want to log out?',
        confirmText: 'Log out');
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
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
        final subscriptionTier = ref.watch(subscriptionProvider).valueOrNull;

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
              if (subscriptionTier == SubscriptionTier.free)
                ListTile(
                  leading:
                      const Icon(Icons.workspace_premium, color: Colors.amber),
                  title: const Text('Upgrade to Gold',
                      style: TextStyle(color: Colors.amber)),
                  subtitle: const Text('Unlock charts and support the app!'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/subscribe'),
                )
              else if (subscriptionTier != null)
                ListTile(
                  leading: const Icon(Icons.credit_card, color: Colors.green),
                  title: const Text('Manage Subscription'),
                  subtitle: Text(
                      'You are a ${subscriptionTier.name.toUpperCase()} member.'),
                  trailing: _isManagingSubscription
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3))
                      : const Icon(Icons.launch, size: 18),
                  onTap: _manageSubscription,
                ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Username'),
                subtitle: Text(user.username),
                trailing:
                    const Icon(Icons.edit_off, color: Colors.grey, size: 18),
                onTap: () => _showFeedbackSnackbar(
                    'Username cannot be changed.',
                    isSuccess: true),
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Gender'),
                subtitle: Text(user.gender ?? "Not specified"),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: _editGender,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Weight'),
                subtitle: Text(user.weight != null
                    ? "${_toDisplayUnit(user, user.weight!).toStringAsFixed(1)} ${_unitLabel(user)}"
                    : "Not specified"),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: _editWeight,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Weight Unit'),
                subtitle: Text(_unitLabel(user) == 'kg'
                    ? "Kilograms (kg)"
                    : "Pounds (lbs)"),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: _editWeightUnit,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Restore Purchases'),
                subtitle: const Text('Re-sync your subscription status'),
                trailing: const Icon(Icons.restore, size: 18),
                onTap: _restorePurchases,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Log out'),
                trailing: const Icon(Icons.logout),
                onTap: _logout,
              ),
            ],
          ),
        );
      },
    );
  }
}
