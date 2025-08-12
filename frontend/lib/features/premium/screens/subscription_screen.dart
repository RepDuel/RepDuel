// frontend/lib/features/premium/screens/subscription_screen.dart

import 'package:flutter/material.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Upgrade to Gold'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium_outlined, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Unlock Your Full Potential',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            _buildFeatureRow('Track your score history with progress charts'),
            _buildFeatureRow('Unlock exclusive "Celestial" rank icon'),
            _buildFeatureRow('Access advanced analytics (coming soon)'),
            _buildFeatureRow('Support the development of RepDuel'),
            const SizedBox(height: 48),

            // --- The Purchase Button ---
            ElevatedButton(
              onPressed: () {
                // TODO: Implement purchase logic for Gold tier
                print("Gold Tier purchase initiated!");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Upgrade for \$4.99 / month',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            
            // --- Restore Purchases & Legal Links (Required by Apple) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: Implement restore purchases logic
                  },
                  child: const Text('Restore Purchases', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
             const SizedBox(height: 16),
             const Text(
              'Subscriptions will be charged to your payment method through your App Store or Stripe account. Your subscription will automatically renew unless cancelled at least 24 hours before the end of the current period.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }

  // Helper widget for a feature list item
  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}