// frontend/lib/features/premium/screens/payment_success_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/core/providers/auth_provider.dart';
import 'package:repduel/widgets/loading_spinner.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  String _statusMessage = 'Finalizing your upgrade...';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    // Start polling for the subscription update after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pollForSubscriptionUpdate();
    });
  }

  /// Periodically polls the backend to check if the subscription status has been
  /// updated via the Stripe webhook.
  Future<void> _pollForSubscriptionUpdate() async {
    const maxRetries = 10; // Poll for up to 20 seconds
    const retryDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      // Fetch the latest user data from the server.
      await ref.read(authProvider.notifier).refreshUserData();

      final user = ref.read(authProvider).valueOrNull?.user;
      if (user != null && user.subscriptionLevel != 'free') {
        debugPrint("Subscription status confirmed on attempt ${i + 1}.");

        if (mounted) {
          // Update the UI to show the success state.
          setState(() {
            _statusMessage = 'Upgrade complete!';
            _isSuccess = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to RepDuel Gold!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Wait briefly so the user sees the success message.
          await Future.delayed(const Duration(seconds: 2));

          // Guard against navigation if the widget was disposed during the delay.
          if (!mounted) return;
          // Use context.go() to cleanly exit the payment flow and reset the stack.
          context.go('/profile');
        }
        return; // Exit the loop on success.
      }

      // Wait before the next retry.
      await Future.delayed(retryDelay);
    }

    // Handle timeout case.
    if (mounted) {
      debugPrint("Timed out waiting for subscription update.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Payment successful! Your account will be updated shortly."),
          duration: Duration(seconds: 5),
        ),
      );
      // Still exit the flow cleanly. The update will appear on next app launch.
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _isSuccess
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 64, key: ValueKey('success'))
                  : const LoadingSpinner(key: ValueKey('loading')),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (!_isSuccess)
              const Padding(
                padding: EdgeInsets.only(top: 12.0),
                child: Text(
                  'Please do not close this page.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
