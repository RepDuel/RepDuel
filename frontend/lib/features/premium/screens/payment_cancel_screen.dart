// frontend/lib/features/premium/screens/payment_cancel_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repduel/core/config/env.dart';

class PaymentCancelScreen extends StatelessWidget {
  const PaymentCancelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/profile'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitle(textTheme),
                  const SizedBox(height: 24),
                  _buildDescription(textTheme),
                  const SizedBox(height: 32),
                  _buildBenefitsReminder(textTheme),
                  const SizedBox(height: 28),
                  _buildPrimaryCta(context),
                  const SizedBox(height: 12),
                  _buildSecondaryCta(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(TextTheme textTheme) {
    return Text(
      'Payment canceled',
      style: textTheme.headlineSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildDescription(TextTheme textTheme) {
    return Text(
      "You weren't charged. You can try again anytime.",
      style: textTheme.bodyMedium?.copyWith(
        color: Colors.white70,
        height: 1.5,
      ),
    );
  }

  Widget _buildBenefitsReminder(TextTheme textTheme) {
    const perks = [
      'Track your score history with progress charts',
      'Unlimited custom routines',
      'Support future development',
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Premium perks',
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < perks.length; i++) ...[
            _buildBenefitItem(textTheme, perks[i]),
            if (i != perks.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitItem(TextTheme textTheme, String text) {
    return Text(
      '• $text',
      style: textTheme.bodyMedium?.copyWith(
        color: Colors.white70,
        height: 1.5,
      ),
    );
  }

  Widget _buildPrimaryCta(BuildContext context) {
    final isEnabled = Env.paymentsEnabled;

    return FilledButton(
      onPressed: isEnabled ? () => context.go('/subscribe') : null,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        isEnabled ? 'Retry payment' : 'Payments unavailable',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSecondaryCta(BuildContext context) {
    return OutlinedButton(
      onPressed: () => context.go('/profile'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Back to profile',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
