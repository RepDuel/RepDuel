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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pollForSubscriptionUpdate();
    });
  }

  Future<void> _pollForSubscriptionUpdate() async {
    const maxRetries = 30;
    const retryDelay = Duration(seconds: 2);

    for (int i = 0; i < maxRetries; i++) {
      await ref.read(authProvider.notifier).refreshUserData();

      final user = ref.read(authProvider).valueOrNull?.user;
      if (user != null && user.subscriptionLevel != 'free') {
        debugPrint("Subscription status confirmed on attempt ${i + 1}.");

        if (mounted) {
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

          await Future.delayed(const Duration(seconds: 2));

          if (!mounted) return;
          context.go('/profile');
        }
        return;
      }

      await Future.delayed(retryDelay);
    }

    if (mounted) {
      debugPrint("Timed out waiting for subscription update.");

      setState(() {
        _statusMessage =
            'We\'re still finalizing things. Your account has not updated yet.';
        _isSuccess = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "We couldn't confirm your upgrade yet. If you completed checkout, "
            'please wait a few minutes or contact support with your receipt.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 6),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
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
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                      key: ValueKey('success'),
                    )
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
