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
      return 'Upgrade now';
    }
    if (_isIOS && iosPriceLabel.isNotEmpty) {
      return 'Upgrade now';
    }
    return 'Upgrade now';
  }

  String _priceLabel(String iosPriceLabel) {
    if (!Env.paymentsEnabled && widget.onSubscribe == null) {
      return 'Temporarily unavailable';
    }
    if (kIsWeb) {
      return '${String.fromCharCode(0x0024)}4.99/month';
    }
    if (_isIOS && iosPriceLabel.isNotEmpty) {
      return iosPriceLabel;
    }
    return 'Monthly subscription';
  }

  Widget _buildBullet(String text) {
    const accentColor = Color(0xFFB1B1B5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.55,
                letterSpacing: -0.1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

    final priceLabel = _priceLabel(iosPriceLabel);

    return Theme(
      data: themedata,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B0B0D), Color(0xFF1A1A1D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _close,
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                              Text(
                                'Premium access',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Ride the momentum.',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Unlock RepDuel Premium for pro-level tracking and elite routines inspired by the world\'s best training teams.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 16,
                              height: 1.45,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.12),
                            thickness: 0.6,
                            height: 0,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Monthly access',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.15,
                            ),
                          ),
                          if (priceLabel.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              priceLabel,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          _buildBullet(
                              'Track your score history with rich, real-time progress charts.'),
                          _buildBullet('Design unlimited custom routines without limits.'),
                          _buildBullet(
                              'Support the future of RepDuel so new features land faster.'),
                          const SizedBox(height: 36),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: FilledButton(
                              key: const Key('cta'),
                              onPressed:
                                  (_isProcessing || isLoadingIOSPrice)
                                      ? null
                                      : _handlePurchase,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                disabledForegroundColor:
                                    Colors.black.withValues(alpha: 0.45),
                                minimumSize: const Size.fromHeight(56),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _ctaLabel(iosPriceLabel),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            alignment: WrapAlignment.start,
                            children: [
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(3),
                                child: TextButton(
                                  key: const Key('privacy'),
                                  onPressed: _openPrivacy,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Colors.white.withValues(alpha: 0.72),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      letterSpacing: -0.1,
                                    ),
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
                                    foregroundColor:
                                        Colors.white.withValues(alpha: 0.72),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                  child: const Text('Terms of Use'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Auto-renews monthly. Cancel anytime in Settings.',
                            style: TextStyle(
                              color: Color(0xFF8F8F93),
                              fontSize: 13,
                              height: 1.45,
                              letterSpacing: -0.05,
                            ),
                          ),
                          if (_isIOS) ...[
                            const SizedBox(height: 20),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: TextButton(
                                key: const Key('restore'),
                                onPressed:
                                    (_isProcessing || isLoadingIOSPrice)
                                        ? null
                                        : _handleRestore,
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Colors.white.withValues(alpha: 0.64),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                child: const Text('Restore purchases'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          Text(
                            _isIOS
                                ? 'Subscriptions are billed to your Apple ID and auto-renew unless cancelled at least 24 hours before the end of the period.'
                                : 'Subscriptions are billed through Stripe and auto-renew monthly unless cancelled at least 24 hours before the end of the period.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              height: 1.5,
                              letterSpacing: -0.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
