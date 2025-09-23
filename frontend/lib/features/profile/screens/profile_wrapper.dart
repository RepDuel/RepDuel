// frontend/lib/features/profile/screens/profile_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repduel/widgets/loading_spinner.dart';

import 'profile_screen.dart';
import '../../auth/screens/register_screen.dart';
import '../../../core/providers/auth_provider.dart';

class ProfileWrapper extends ConsumerWidget {
  const ProfileWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      data: (authState) {
        final isAuthenticated = authState.token != null;
        return isAuthenticated ? const ProfileScreen() : const RegisterScreen();
      },
      loading: () => const Center(child: LoadingSpinner()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
