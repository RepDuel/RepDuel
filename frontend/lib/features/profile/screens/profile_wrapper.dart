// frontend/lib/features/profile/screens/profile_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_screen.dart';
import '../../auth/screens/register_screen.dart';
import '../../../core/providers/auth_provider.dart';

class ProfileWrapper extends ConsumerWidget {
  const ProfileWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.token != null;

    if (isAuthenticated) {
      return const ProfileScreen();
    } else {
      return const RegisterScreen();
    }
  }
}
