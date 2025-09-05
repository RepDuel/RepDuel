// frontend/lib/features/premium/screens/subscription_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:repduel/core/providers/iap_provider.dart';
import 'package:repduel/core/providers/stripe_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isPurchasing = false;

  Future<void> _handlePurchase() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    try {
      if (kIsWeb) {
        // Web flow remains the same, as it relies on redirects
        await ref.read(stripeServiceProvider).subscribeToPlan(
            onDisplayError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error), backgroundColor: Colors.red));
          }
        });
      } else {
        // Native iOS/Android Flow
        final offerings = await ref.read(offeringsProvider.future);
        final packageToPurchase = offerings.current?.availablePackages.first;

        if (packageToPurchase == null) {
          throw Exception("No products found.");
        }

        // Await the purchase result
        await ref
            .read(subscriptionProvider.notifier)
            .purchasePackage(packageToPurchase);

        // ========== THIS IS THE FIX ==========
        // If the purchase was successful and didn't throw an error,
        // we can assume success and navigate.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Success! Premium features unlocked."),
              backgroundColor: Colors.green));
          context.pop();
        }
        // =====================================
      }
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Purchase failed: ${e.message}"),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("An error occurred: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Restoring purchases...")));

    try {
      await ref.read(subscriptionProvider.notifier).restorePurchases();

      // ========== THIS IS THE FIX ==========
      // If the restore was successful and didn't throw an error,
      // show a success message and navigate.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Purchases restored successfully!"),
            backgroundColor: Colors.green));
        context.pop();
      }
      // =====================================
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Restore failed: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We no longer need the ref.listen in the build method.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Upgrade to Gold'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium_outlined,
                color: Colors.amber, size: 64),
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
            _buildFeatureRow('Support the development of RepDuel'),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isPurchasing ? null : _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade700,
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text(
                      'Upgrade for \$4.99 / month',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: _isPurchasing ? null : _handleRestore,
                  child: const Text('Restore Purchases',
                      style: TextStyle(color: Colors.white70)),
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
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
