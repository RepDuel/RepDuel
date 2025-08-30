import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaymentCancelScreen extends StatelessWidget {
  const PaymentCancelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // The close button provides a clean exit from the payment flow.
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/profile'),
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
                      _buildCancelIcon(),
                      const SizedBox(height: 32),
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildDescription(),
                      const SizedBox(height: 48),
                      _buildBenefitsReminder(),
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

  Widget _buildCancelIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(51),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: const Icon(
        Icons.cancel_outlined,
        color: Colors.red,
        size: 50,
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Payment Canceled',
      style: TextStyle(
          color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription() {
    return const Text(
      'Your payment process was canceled. You have not been charged.',
      style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildBenefitsReminder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withAlpha(77), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Premium Benefits You\'re Missing:',
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBenefitItem('View historical progress charts'),
          _buildBenefitItem('Support the development of RepDuel'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 16),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          // --- THIS IS THE FIX ---
          // Use context.go() to navigate to a known, safe state. This is robust
          // and works correctly even after a full-page web redirect.
          onPressed: () => context.go('/subscribe'),
          // --- END OF FIX ---
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Try Again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          // This already correctly uses go() to provide a clean exit.
          onPressed: () => context.go('/profile'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Not Now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
