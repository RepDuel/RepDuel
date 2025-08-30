// frontend/lib/features/premium/screens/payment_cancel_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PaymentCancelScreen extends ConsumerWidget {
  const PaymentCancelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color withOpacity(Color color, double opacity) =>
        color.withAlpha((opacity * 255).round());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => _navigateToSubscription(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      _buildCancelIcon(withOpacity),
                      const SizedBox(height: 32),
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildDescription(),
                      const SizedBox(height: 48),
                      _buildBenefitsReminder(withOpacity),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelIcon(Color Function(Color, double) withOpacity) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: withOpacity(Colors.orange, 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.pause_circle_outline,
        color: Colors.orange,
        size: 50,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Payment Cancelled',
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription() {
    return const Text(
      'No worries! Your payment was cancelled and you haven\'t been charged.',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 16,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBenefitsReminder(Color Function(Color, double) withOpacity) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: withOpacity(Colors.amber, 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Premium Benefits You\'re Missing:',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(Icons.fitness_center, 'Unlimited custom routines'),
          _buildBenefitItem(Icons.analytics, 'Advanced progress tracking'),
          _buildBenefitItem(Icons.leaderboard, 'Global leaderboards'),
          _buildBenefitItem(Icons.cloud_sync, 'Cloud sync across devices'),
          _buildBenefitItem(Icons.support, 'Priority customer support'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => _navigateToSubscription(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Try Again',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _navigateToHome(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Continue with Free Version',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToSubscription(BuildContext context) {
    context.go('/subscribe');
  }

  void _navigateToHome(BuildContext context) {
    context.go('/profile');
  }
}
