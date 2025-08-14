// frontend/lib/features/premium/screens/payment_success_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/core/providers/auth_provider.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure the build method has completed
    // and we have a valid context before performing async operations.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finalizePurchase();
    });
  }

  Future<void> _finalizePurchase() async {
    // This is the "last mile" step.
    // 1. We call the new method to refresh the user's data from the server.
    //    This will update their subscription_level in the app's state.
    await ref.read(authProvider.notifier).refreshUserData();
    
    // 2. After the data is refreshed, navigate the user to their profile.
    //    We use context.go to replace the current screen in the navigation stack.
    if (mounted) {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    // This screen provides immediate feedback to the user while we work
    // in the background.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.amber,
            ),
            SizedBox(height: 24),
            Text(
              'Finalizing your upgrade...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}