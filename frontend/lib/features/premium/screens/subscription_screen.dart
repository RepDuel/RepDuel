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
    } else if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop(result);
    } else {
      context.go(widget.fallbackLocation?.isNotEmpty == true
          ? widget.fallbackLocation!
          : '/routines');
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: TextStyle(color: isError ? Colors.white : Colors.black)),
        backgroundColor: isError ? Colors.red : Colors.white,
      ),
    );
  }

  Future<void> _handlePurchase() async {
    if (_isProcessing) {
      return;
    }
    if (!Env.paymentsEnabled && widget.onSubscribe == null) {
      _showSnackbar('Subscriptions are temporarily unavailable.',
          isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      if (widget.onSubscribe != null) {
        await widget.onSubscribe!();
      } else if (kIsWeb) {
        await ref.read(stripeServiceProvider).subscribeToPlan(
          onDisplayError: (error) {
            _showSnackbar(error, isError: true);
          },
        );
        if (!mounted) {
          return;
        }
        _showSnackbar('Checkout opened. Complete payment to unlock features.');
      } else if (_isIOS) {
        final offerings = await ref.read(offeringsProvider.future);
        final package = offerings.current?.availablePackages.firstOrNull;
        if (package == null) {
          throw PlatformException(
              code: 'no_products', message: 'No products found.');
        }
        final success = await ref
            .read(subscriptionProvider.notifier)
            .purchasePackage(package);
        if (!success) {
          setState(() => _isProcessing = false);
          return;
        }
      } else {
        _showSnackbar('In-app purchases not supported on this platform.',
            isError: true);
        setState(() => _isProcessing = false);
        return;
      }
      if (!mounted) {
        return;
      }
      _showSnackbar('Success! Premium features unlocked.');
      _close(true);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
        _showSnackbar('Purchase failed: ${e.message}', isError: true);
      }
    } catch (e) {
      _showSnackbar('An error occurred: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _ctaLabel(String iosPriceLabel) => _isProcessing
      ? 'Processing…'
      : !Env.paymentsEnabled && widget.onSubscribe == null
          ? 'Unavailable right now'
          : 'Upgrade now';

  String _priceLabel(String iosPriceLabel) {
    if (!Env.paymentsEnabled && widget.onSubscribe == null) {
      return 'Temporarily unavailable';
    }
    if (kIsWeb) return '\$0.99/month';
    return _isIOS && iosPriceLabel.isNotEmpty
        ? iosPriceLabel
        : 'Monthly subscription';
  }

  Widget _buildFeature(ThemeData theme, String text) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Text(text,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white))),
        ],
      );

  String _formatIOSPrice(StoreProduct product) {
    final raw = product.priceString.trim();
    if (raw.isEmpty) return raw;
    final lower = raw.toLowerCase();
    return lower.contains('/month') ||
            lower.contains('per month') ||
            lower.contains('monthly')
        ? raw
        : '$raw/month';
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = _isIOS ? ref.watch(offeringsProvider) : null;
    final isLoadingPrice = offeringsAsync?.isLoading ?? false;
    final iosPackage = offeringsAsync?.hasValue == true
        ? offeringsAsync!.value?.current?.availablePackages.firstOrNull
        : null;
    final iosPriceLabel =
        iosPackage != null ? _formatIOSPrice(iosPackage.storeProduct) : '';
    final theme = Theme.of(context);
    final isSmall = MediaQuery.of(context).size.height < 700;
    final darkTheme = ThemeData.from(
      colorScheme: ColorScheme.dark(
          brightness: Brightness.dark,
          surface: Colors.black,
          primary: Colors.white),
      textTheme: theme.textTheme,
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: Colors.black,
      textTheme: theme.textTheme
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
    );

    return Theme(
      data: darkTheme,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width < 360 ? 16 : 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text('Go Premium',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.all(isSmall ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFeature(theme, 'Unlock progress charts!'),
                              SizedBox(height: isSmall ? 8 : 12),
                              _buildFeature(
                                  theme, 'Unlock unlimited routines!'),
                              SizedBox(height: isSmall ? 8 : 12),
                              _buildFeature(theme, 'Support development!'),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmall ? 16 : 24),
                        Center(
                          child: Text(
                              '${_priceLabel(iosPriceLabel)} • Auto-renews monthly. Cancel anytime.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[500])),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              TextButton(
                                key: const Key('privacy'),
                                onPressed: () => _launchUrl(
                                    'https://repduel.github.io/repduel-website/privacy.html'),
                                child: Text('Privacy Policy',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[500])),
                              ),
                              Text('•',
                                  style: TextStyle(color: Colors.grey[600])),
                              TextButton(
                                key: const Key('terms'),
                                onPressed: () => _launchUrl(
                                    'https://repduel.github.io/repduel-website/terms.html'),
                                child: Text('Terms of Use',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[500])),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const Key('cta'),
                            onPressed: (_isProcessing || isLoadingPrice)
                                ? null
                                : _handlePurchase,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                minimumSize: const Size(double.infinity, 48)),
                            child: Text(_ctaLabel(iosPriceLabel),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                              onPressed: _close,
                              child: Text('Maybe Later...',
                                  style: TextStyle(color: Colors.grey[500]))),
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
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
