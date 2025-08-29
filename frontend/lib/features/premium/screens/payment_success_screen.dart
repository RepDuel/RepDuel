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
  ConsumerState<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  // --- THIS IS THE FIX: Add state to manage the UI ---
  String _statusMessage = 'Finalizing your upgrade...';
  bool _isSuccess = false;
  // --- END OF FIX ---

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pollForSubscriptionUpdate();
    });
  }

  Future<void> _pollForSubscriptionUpdate() async {
    const maxRetries = 10;
    const retryDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      await ref.read(authProvider.notifier).refreshUserData();
      
      final user = ref.read(authProvider).valueOrNull?.user;
      if (user != null && user.subscriptionLevel != 'free') {
        debugPrint("Subscription status confirmed on attempt ${i + 1}.");
        
        // --- THIS IS THE FIX: Update UI before navigating ---
        if (mounted) {
          setState(() {
            _statusMessage = 'Upgrade complete!';
            _isSuccess = true;
          });
          
          // Show a success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to RepDuel Gold!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Wait 2 seconds on the success screen before redirecting
          await Future.delayed(const Duration(seconds: 2));
          context.go('/profile');
        }
        // --- END OF FIX ---
        return; 
      }
      
      await Future.delayed(retryDelay);
    }
    
    if (mounted) {
      debugPrint("Timed out waiting for subscription update.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment successful! Your account will be updated shortly."),
          duration: Duration(seconds: 5),
        ),
      );
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
            // --- THIS IS THE FIX: Animate between spinner and checkmark ---
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _isSuccess
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 64)
                  : const LoadingSpinner(),
            ),
            // --- END OF FIX ---
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (!_isSuccess) // Only show this message while loading
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