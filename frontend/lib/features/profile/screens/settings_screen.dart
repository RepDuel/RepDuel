// frontend/lib/features/profile/screens/settings_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user.dart';
import '../../../core/providers/api_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/iap_provider.dart';
import '../../../core/providers/score_events_provider.dart';
import '../../../router/app_router.dart' show rootNavigatorKey;
import '../../../widgets/loading_spinner.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isManagingSubscription = false;
  // ignore: prefer_final_fields
  bool _isDeletingScores = false;
  bool _isDeletingAccount = false;

  static final List<RegExp> _offensivePatterns = [
    RegExp(r'\bnigg+(?:er|a)\b', caseSensitive: false, unicode: true),
    RegExp(r'\bfagg(?:ot)?\b', caseSensitive: false, unicode: true),
  ];

  double _toDisplayUnit(User user, double value) =>
      value * user.weightMultiplier;
  String _unitLabel(User user) => user.preferredUnit; // 'kg' or 'lbs'

  bool _containsOffensiveLanguage(String value) {
    for (final pattern in _offensivePatterns) {
      if (pattern.hasMatch(value)) {
        return true;
      }
    }
    return false;
  }

  void _showFeedbackSnackbar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isSuccess ? Colors.black : Colors.white,
          ),
        ),
        backgroundColor: isSuccess ? Colors.white : Colors.red,
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
        title: Text(
          title,
          style: TextStyle(color: isDestructive ? Colors.red : Colors.white),
        ),
        content: Text(content),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? Colors.red : Colors.amber,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _manageSubscription() async {
    if (_isManagingSubscription) return;
    setState(() => _isManagingSubscription = true);

    try {
      if (kIsWeb) {
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
        final customerInfo = await Purchases.getCustomerInfo();
        final managementURL = customerInfo.managementURL;

        if (managementURL == null) {
          throw Exception("Could not find subscription management URL.");
        }

        final uri = Uri.parse(managementURL);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['detail'] != null)
          ? data['detail'].toString()
          : 'Failed to open subscription portal.';
      _showFeedbackSnackbar(message, isSuccess: false);
    } catch (e) {
      _showFeedbackSnackbar(e.toString().replaceFirst("Exception: ", ""),
          isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _isManagingSubscription = false);
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    final success =
        await ref.read(authProvider.notifier).updateProfilePictureFromBytes(
              bytes,
              pickedFile.name,
              pickedFile.mimeType ?? 'image/jpeg',
            );
    _showFeedbackSnackbar(
      success
          ? 'Profile picture updated!'
          : 'Failed to update profile picture.',
      isSuccess: success,
    );
  }

  Future<void> _editDisplayName() async {
    final user = ref.read(authProvider).valueOrNull?.user;
    if (user == null) return;

    final controller = TextEditingController(
      text: user.displayName ?? user.username,
    );

    final updatedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Display Name"),
        backgroundColor: Colors.grey[900],
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text("Save", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );

    controller.dispose();

    if (updatedName == null) return;

    if (updatedName.isEmpty) {
      _showFeedbackSnackbar('Display name cannot be empty.', isSuccess: false);
      return;
    }

    if (updatedName.length > 50) {
      _showFeedbackSnackbar(
        'Display name must be 50 characters or less.',
        isSuccess: false,
      );
      return;
    }

    if (_containsOffensiveLanguage(updatedName)) {
      _showFeedbackSnackbar(
        'Display name contains disallowed language.',
        isSuccess: false,
      );
      return;
    }

    if (updatedName == (user.displayName ?? user.username)) {
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .updateUser(displayName: updatedName);

    _showFeedbackSnackbar(
      success ? 'Display name updated!' : 'Failed to update display name.',
      isSuccess: success,
    );
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
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text("Save", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
    if (newWeightString != null) {
      final newWeightInUserUnits = double.tryParse(newWeightString);
      if (newWeightInUserUnits != null && newWeightInUserUnits > 0) {
        // Store in kg; backend stores kg
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
              title: Text(option, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(dialogContext, option),
            );
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

    final isKg = user.preferredUnit == 'kg';
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
              selected: isKg,
            ),
            ListTile(
              title: const Text('Pounds (lbs)'),
              onTap: () => Navigator.pop(dialogContext, 'lbs'),
              selected: !isKg,
            ),
          ],
        ),
      ),
    );

    if (newUnit != null && newUnit != user.preferredUnit) {
      final success =
          await ref.read(authProvider.notifier).setPreferredUnit(newUnit);
      _showFeedbackSnackbar(
        success ? 'Weight unit updated!' : 'Failed to update weight unit.',
        isSuccess: success,
      );
      if (success && mounted) {
        // Optionally refresh user to pull any server-side recalcs
        await ref.read(authProvider.notifier).refreshUserData();
      }
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

  void _navigateToLogin() {
    final rootContext = rootNavigatorKey.currentContext;
    if (rootContext != null) {
      rootContext.go('/login');
    } else if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _logout() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Log out',
      content: 'Are you sure you want to log out?',
      confirmText: 'Log out',
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      _navigateToLogin();
    }
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    final confirmed = await _showConfirmationDialog(
      title: 'Delete Account',
      content:
          'This will permanently delete your account and all associated data. This cannot be undone.',
      confirmText: 'Delete Account',
      isDestructive: true,
    );
    if (confirmed != true) return;

    setState(() => _isDeletingAccount = true);
    try {
      final client = ref.read(privateHttpClientProvider);
      await client.delete('/users/me');
      if (mounted) {
        _showFeedbackSnackbar('Account deleted.', isSuccess: true);
      }
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      _navigateToLogin();
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map<String, dynamic> && data['detail'] != null)
          ? data['detail'].toString()
          : 'Failed to delete account.';
      _showFeedbackSnackbar(message, isSuccess: false);
    } catch (e) {
      _showFeedbackSnackbar('Failed to delete account: $e', isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return true;
    }
    return !uri.hasScheme && uri.hasAbsolutePath;
  }

  bool _isAssetPath(String? url) {
    return url != null && url.isNotEmpty && url.startsWith('assets/');
  }

  ImageProvider<Object> _resolveAvatarImage(String? url) {
    if (_isValidImageUrl(url)) {
      return NetworkImage(url!);
    }
    if (_isAssetPath(url)) {
      return AssetImage(url!);
    }
    return const AssetImage('assets/images/default_nonbinary.png');
  }

  @override
  Widget build(BuildContext context) {
    final authStateAsyncValue = ref.watch(authProvider);

    return authStateAsyncValue.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: LoadingSpinner()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child:
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (authState) {
        final user = authState.user;
        final subscriptionTier = ref.watch(subscriptionProvider).valueOrNull;

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
            elevation: 0,
          ),
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
                      backgroundImage: _resolveAvatarImage(user.avatarUrl),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to change picture',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                key: const Key('settings_subscription_entry'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Text(
                  subscriptionTier == null ||
                          subscriptionTier == SubscriptionTier.free
                      ? 'Subscribe to RepDuel Gold'
                      : subscriptionTier.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  subscriptionTier == null ||
                          subscriptionTier == SubscriptionTier.free
                      ? r'$4.99/mo'
                      : r'$4.99/mo · Active',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: _isManagingSubscription
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: LoadingSpinner(size: 24),
                      )
                    : null,
                onTap: _isManagingSubscription
                    ? null
                    : () {
                        if (subscriptionTier == null ||
                            subscriptionTier == SubscriptionTier.free) {
                          context.push(
                            '/subscribe',
                            extra: GoRouterState.of(context).uri.toString(),
                          );
                        } else {
                          _manageSubscription();
                        }
                      },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Username'),
                subtitle: Text(user.username),
                onTap: () => _showFeedbackSnackbar(
                    'Username cannot be changed.',
                    isSuccess: true),
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Display Name'),
                subtitle: Text(
                  (user.displayName != null &&
                          user.displayName!.trim().isNotEmpty)
                      ? user.displayName!
                      : 'Not set',
                ),
                onTap: _editDisplayName,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Gender'),
                subtitle: Text(user.gender ?? "Not specified"),
                onTap: _editGender,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Weight'),
                subtitle: Text(
                  user.weight != null
                      ? "${_toDisplayUnit(user, user.weight!).toStringAsFixed(1)} ${_unitLabel(user)}"
                      : "Not specified",
                ),
                onTap: _editWeight,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Weight Unit'),
                subtitle: Text(user.preferredUnit == 'kg'
                    ? "Kilograms (kg)"
                    : "Pounds (lbs)"),
                onTap: _editWeightUnit,
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Restore Purchases'),
                subtitle: const Text('Re-sync your subscription status'),
                onTap: _restorePurchases,
              ),
              // Insert this just before the "Log out" tile
              const Divider(color: Colors.grey),
              ListTile(
                title: const Text(
                  'Delete All Scores',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle:
                    const Text('Remove all your scores across all scenarios'),
                trailing: _isDeletingScores
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: LoadingSpinner(size: 24),
                      )
                    : null,
                onTap: () async {
                  final confirmed = await _showConfirmationDialog(
                    title: 'Delete All Scores',
                    content:
                        'This will permanently remove ALL your scores across ALL scenarios. This cannot be undone.',
                    confirmText: 'Delete',
                    isDestructive: true,
                  );
                  if (confirmed != true) return;

                  setState(() => _isDeletingScores = true);
                  try {
                    final client = ref.read(privateHttpClientProvider);
                    final userId = ref.read(authProvider).valueOrNull?.user?.id;
                    if (userId == null) {
                      _showFeedbackSnackbar(
                          'No user found. Please log in again.',
                          isSuccess: false);
                      return;
                    }

                    await client.delete('/scores/user/$userId');

                    // Refresh user & notify rest of app that scores changed
                    await ref.read(authProvider.notifier).refreshUserData();
                    ref.read(scoreEventsProvider.notifier).state++;

                    _showFeedbackSnackbar('All scores deleted.',
                        isSuccess: true);
                  } on DioException catch (e) {
                    if (e.response?.statusCode == 404) {
                      // Treat as success + notify listeners too
                      ref.read(scoreEventsProvider.notifier).state++;
                      _showFeedbackSnackbar('No scores to delete.',
                          isSuccess: true);
                    } else {
                      final data = e.response?.data;
                      final String msg = (data is Map<String, dynamic> &&
                              data['detail'] != null)
                          ? data['detail'].toString()
                          : 'Failed to delete scores.';
                      _showFeedbackSnackbar(msg, isSuccess: false);
                    }
                  } catch (e) {
                    _showFeedbackSnackbar('Failed to delete scores: $e',
                        isSuccess: false);
                  } finally {
                    if (mounted) setState(() => _isDeletingScores = false);
                  }
                },
              ),

              const Divider(color: Colors.grey),
              ListTile(
                title: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                    'Permanently remove your account and personal data'),
                trailing: _isDeletingAccount
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: LoadingSpinner(size: 24),
                      )
                    : null,
                onTap: _deleteAccount,
              ),

              const Divider(color: Colors.grey),
              ListTile(
                title: const Text('Log out'),
                onTap: _logout,
              ),
            ],
          ),
        );
      },
    );
  }
}
