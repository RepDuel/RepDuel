// frontend/lib/features/premium/screens/subscription_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/iap_provider.dart';
import 'package:repduel/core/providers/stripe_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({
    super.key,
    this.fallbackLocation,
    this.onSubscribe,
    this.onRestore,
    this.onViewPrivacy,
    this.onViewTerms,
  });

  final String? fallbackLocation;
  final Future<void> Function()? onSubscribe;
  final Future<void> Function()? onRestore;
  final VoidCallback? onViewPrivacy;
  final VoidCallback? onViewTerms;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isProcessing = false;

  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _close([bool? result]) {
    if (context.canPop()) {
      context.pop(result);
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (rootNavigator.canPop()) {
      rootNavigator.pop(result);
      return;
    }

    final fallback = widget.fallbackLocation;
    if (fallback != null && fallback.isNotEmpty) {
      context.go(fallback);
    } else {
      context.go('/routines');
    }
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handlePurchase() async {
    if (_isProcessing) return;

    if (!Env.paymentsEnabled && widget.onSubscribe == null) {
      _showErrorSnackbar('Subscriptions are temporarily unavailable.');
      return;
    }

    setState(() => _isProcessing = true);

    bool shouldShowSuccess = true;

    try {
      if (widget.onSubscribe != null) {
        await widget.onSubscribe!();
      } else if (kIsWeb) {
        var encounteredError = false;
        await ref.read(stripeServiceProvider).subscribeToPlan(
          onDisplayError: (error) {
            shouldShowSuccess = false;
            encounteredError = true;
            _showErrorSnackbar(error);
          },
        );
        if (!mounted || encounteredError) return;
        shouldShowSuccess = false;
        _showInfoSnackbar(
            'Checkout opened. Complete payment to unlock features.');
      } else if (_isIOS) {
        final offerings = await ref.read(offeringsProvider.future);
        final packageToPurchase =
            offerings.current?.availablePackages.firstOrNull;
        if (packageToPurchase == null) {
          throw PlatformException(
              code: 'no_products', message: 'No products found.');
        }

        final purchaseCompleted = await ref
            .read(subscriptionProvider.notifier)
            .purchasePackage(packageToPurchase);
        if (!purchaseCompleted) {
          shouldShowSuccess = false;
        }
      } else {
        shouldShowSuccess = false;
        _showErrorSnackbar(
            'In-app purchases are not supported on this platform yet.');
        return;
      }

      if (!mounted || !shouldShowSuccess) return;

      _showInfoSnackbar('Success! Premium features unlocked.');
      _close(true);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        _showErrorSnackbar('Purchase failed: ${e.message}');
      }
    } catch (e) {
      _showErrorSnackbar('An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    if (_isProcessing || !_isIOS) return;

    setState(() => _isProcessing = true);

    _showInfoSnackbar('Restoring purchases...');

    try {
      if (widget.onRestore != null) {
        await widget.onRestore!();
      } else {
        await ref.read(subscriptionProvider.notifier).restorePurchases();
      }

      if (!mounted) return;

      _showInfoSnackbar('Purchases restored successfully!');
      _close(true);
    } catch (e) {
      _showErrorSnackbar('Restore failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openPrivacy() async {
    if (widget.onViewPrivacy != null) {
      widget.onViewPrivacy!();
      return;
    }
    await _launchExternalUrl(
        'https://repduel.github.io/repduel-website/privacy.html');
  }

  Future<void> _openTerms() async {
    if (widget.onViewTerms != null) {
      widget.onViewTerms!();
      return;
    }
    await _launchExternalUrl(
        'https://repduel.github.io/repduel-website/terms.html');
  }

  Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _ctaLabel(String iosPriceLabel) {
    if (_isProcessing) {
      return 'Processing…';
    }
    if (!Env.paymentsEnabled && widget.onSubscribe == null) {
      return 'Unavailable right now';
    }
    if (kIsWeb) {
      return r'Upgrade — $4.99/month';
    }
    if (_isIOS && iosPriceLabel.isNotEmpty) {
      return 'Upgrade — $iosPriceLabel';
    }
    return 'Upgrade';
  }

  Widget _buildBullet(String text) {
    return Text(
      '• $text',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        height: 1.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Offerings>? offeringsAsync =
        _isIOS ? ref.watch(offeringsProvider) : null;

    final bool isLoadingIOSPrice = offeringsAsync?.isLoading ?? false;
    final Package? iosPackage = offeringsAsync?.hasValue ?? false
        ? offeringsAsync!.value?.current?.availablePackages.firstOrNull
        : null;
    final String iosPriceLabel = iosPackage != null
        ? _formatIOSPriceLabel(iosPackage.storeProduct)
        : '';

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme.copyWith(
      brightness: Brightness.dark,
      surface: Colors.black,
      primary: Colors.white,
      onPrimary: Colors.black,
      onSurface: Colors.white,
    );

    final themedata = ThemeData.from(
      colorScheme: colorScheme,
      textTheme: theme.textTheme,
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: Colors.black,
      textTheme: theme.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );

    return Theme(
      data: themedata,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _close,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unlock Your Full Potential',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildBullet(
                              'Track your score history with progress charts'),
                          const SizedBox(height: 14),
                          _buildBullet('Unlimited custom routines'),
                          const SizedBox(height: 14),
                          _buildBullet('Support future development'),
                          const SizedBox(height: 32),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: FilledButton(
                              key: const Key('cta'),
                              onPressed: (_isProcessing || isLoadingIOSPrice)
                                  ? null
                                  : _handlePurchase,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: Colors.white24,
                                disabledForegroundColor: Colors.black54,
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _ctaLabel(iosPriceLabel),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(3),
                                child: TextButton(
                                  key: const Key('privacy'),
                                  onPressed: _openPrivacy,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Privacy Policy'),
                                ),
                              ),
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(4),
                                child: TextButton(
                                  key: const Key('terms'),
                                  onPressed: _openTerms,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Terms of Use'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Auto-renews monthly. Cancel anytime in Settings.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          if (_isIOS) ...[
                            const SizedBox(height: 24),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: TextButton(
                                key: const Key('restore'),
                                onPressed: (_isProcessing || isLoadingIOSPrice)
                                    ? null
                                    : _handleRestore,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('Restore Purchases'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            _isIOS
                                ? 'Subscriptions are billed to your Apple ID and auto-renew unless cancelled at least 24 hours before the end of the period.'
                                : 'Subscriptions are billed through Stripe and auto-renew monthly unless cancelled at least 24 hours before the end of the period.',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatIOSPriceLabel(StoreProduct product) {
    final rawLabel = product.priceString.trim();
    if (rawLabel.isEmpty) {
      return rawLabel;
    }

    final normalized = rawLabel.toLowerCase();
    if (normalized.contains('/month') ||
        normalized.contains('per month') ||
        normalized.contains('monthly')) {
      return rawLabel;
    }

    return '$rawLabel/month';
  }

}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
