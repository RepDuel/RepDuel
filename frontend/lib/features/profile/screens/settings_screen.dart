import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editWeight(BuildContext context, WidgetRef ref) async {
    final authNotifier = ref.read(authProvider.notifier);
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
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null) {
      final weight = double.tryParse(result);
      if (weight != null) {
        await authNotifier.updateUser(weight: weight);
      }
    }
  }

  Future<void> _editGender(BuildContext context, WidgetRef ref) async {
    final authNotifier = ref.read(authProvider.notifier);
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
          children: ['Male', 'Female', 'Other'].map((option) {
            return ListTile(
              title: Text(option, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, option),
            );
          }).toList(),
        ),
      ),
    );

    if (result != null && result != user.gender) {
      await authNotifier.updateUser(gender: result);
    }
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
              ],
            ),
    );
  }
}
