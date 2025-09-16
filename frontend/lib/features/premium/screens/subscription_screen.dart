// frontend/lib/features/premium/screens/subscription_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:repduel/core/providers/iap_provider.dart';
import 'package:repduel/core/providers/stripe_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
        await ref.read(stripeServiceProvider).subscribeToPlan(
            onDisplayError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        });
      } else {
        final offerings = await ref.read(offeringsProvider.future);
        final packageToPurchase =
            offerings.current?.availablePackages.firstOrNull;
        if (packageToPurchase == null) {
          throw PlatformException(
              code: 'no_products', message: 'No products found.');
        }

        await ref
            .read(subscriptionProvider.notifier)
            .purchasePackage(packageToPurchase);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Success! Premium features unlocked."),
              backgroundColor: Colors.green,
            ),
          );
          context.pop(true);
        }
      }
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Purchase failed: ${e.message}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("An error occurred: $e"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _handleRestore() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Restore Purchases is available on the iOS app."),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Restoring purchases...")),
    );

    try {
      await ref.read(subscriptionProvider.notifier).restorePurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Purchases restored successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Restore failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = kIsWeb
        ? const AsyncValue<Offerings>.data(Offerings(<String, Offering>{}))
        : ref.watch(offeringsProvider);

    final bool isLoadingIOSPrice = !kIsWeb && offeringsAsync.isLoading;
    final Package? iosPackage = !kIsWeb && offeringsAsync.hasValue
        ? offeringsAsync.value?.current?.availablePackages.firstOrNull
        : null;

    final String iosPriceLabel = iosPackage?.storeProduct.priceString ?? '';

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
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildFeatureRow('Track your score history with progress charts'),
            _buildFeatureRow('Support the development of RepDuel'),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed:
                  (_isPurchasing || isLoadingIOSPrice) ? null : _handlePurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.shade700,
              ),
              child: (_isPurchasing || isLoadingIOSPrice)
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 3),
                    )
                  : Text(
                      kIsWeb
                          ? 'Upgrade for \$4.99 / month'
                          : (iosPriceLabel.isNotEmpty
                              ? 'Upgrade for $iosPriceLabel'
                              : 'Upgrade'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: (_isPurchasing || isLoadingIOSPrice)
                      ? null
                      : _handleRestore,
                  child: const Text('Restore Purchases',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (kIsWeb)
              const Text(
                'Subscriptions will be charged to your payment method through your Stripe account. '
                'Your subscription will automatically renew unless cancelled at least 24 hours before the end of the current period.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              )
            else
              const Text(
                'Subscriptions are billed to your Apple ID via the App Store and auto-renew until cancelled. '
                'You can manage or cancel your subscription in iOS Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _openLink(
                      'https://repduel.github.io/repduel-website/privacy.html'),
                  child: const Text('Privacy Policy'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => _openLink(
                      'https://repduel.github.io/repduel-website/terms.html'),
                  child: const Text('Terms of Use'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Required subscription disclosure details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gold Subscription Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Length: 1 month (auto-renewing)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kIsWeb
                        ? 'Price: \$4.99 per month'
                        : (iosPriceLabel.isNotEmpty
                            ? 'Price: $iosPriceLabel per month'
                            : 'Price: see purchase sheet'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
