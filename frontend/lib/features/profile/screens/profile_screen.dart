import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../widgets/main_bottom_nav_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _editWeight(BuildContext context) async {
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

  Future<void> _editGender(BuildContext context) async {
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
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? const Center(
                child: Text(
                  'User not found.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                ? Image.network(
                                    user.avatarUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    'assets/images/profile_placeholder.png',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Gender: ${user.gender ?? "Unknown"}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () => _editGender(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Weight: ${user.weight?.toStringAsFixed(1) ?? "N/A"} kg',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () => _editWeight(context),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          // Navigation handled in MainBottomNavBar
        },
      ),
    );
  }
}
