// frontend/lib/core/providers/iap_provider.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';

// --- Configuration & Data Models (Unchanged) ---
const String _goldEntitlementId = 'gold';
const String _platinumEntitlementId = 'platinum';

enum SubscriptionTier { free, gold, platinum }

// --- Provider Definitions (Unchanged) ---
final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, AsyncValue<SubscriptionTier>>(
  (ref) => SubscriptionNotifier(ref),
);

final offeringsProvider = FutureProvider<Offerings>((ref) async {
  if (kIsWeb) return Offerings(<String, Offering>{}); 
  try {
    return await Purchases.getOfferings();
  } on PlatformException catch (e) {
    debugPrint("[iap_provider] Failed to fetch offerings: ${e.message}");
    throw Exception("Failed to fetch offerings: ${e.message}");
  }
});


// --- State Notifier ---
class SubscriptionNotifier extends StateNotifier<AsyncValue<SubscriptionTier>> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
    if (!kIsWeb) {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    _ref.listen(authProvider, (_, __) {
      debugPrint("[SubscriptionNotifier] Auth state changed, re-evaluating subscription status.");
      _updateSubscriptionStatus();
    });
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }

  Future<void> _init() async {
    state = const AsyncValue.loading();
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
        await Purchases.configure(PurchasesConfiguration(Env.revenueCatAppleKey));
        debugPrint("[SubscriptionNotifier] RevenueCat configured for iOS.");
      }
      await _updateSubscriptionStatus();
    } on PlatformException catch (e, s) {
      state = AsyncValue.error("Failed to initialize purchases: ${e.message}", s);
    } catch (e, s) {
      state = AsyncValue.error("An unexpected error occurred during init: $e", s);
    }
  }

  /// Determines the user's subscription tier and syncs it with the backend if needed.
  Future<void> _updateSubscriptionStatus() async {
    final user = _ref.read(authProvider).valueOrNull?.user;
    final backendSubLevel = user?.subscriptionLevel ?? 'free';
    
    SubscriptionTier tierFromBackend = SubscriptionTier.values.byName(backendSubLevel);
    debugPrint("[SubscriptionNotifier] Backend subscription tier: $tierFromBackend");

    SubscriptionTier tierFromNative = SubscriptionTier.free;
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        if (customerInfo.entitlements.active[_platinumEntitlementId] != null) {
          tierFromNative = SubscriptionTier.platinum;
        } else if (customerInfo.entitlements.active[_goldEntitlementId] != null) {
          tierFromNative = SubscriptionTier.gold;
        }
        debugPrint("[SubscriptionNotifier] Native subscription tier: $tierFromNative");
      } catch (e) {
        debugPrint("[SubscriptionNotifier] Could not get native customer info: $e. Relying on backend.");
      }
    }
    
    final finalTier = tierFromNative.index > tierFromBackend.index ? tierFromNative : tierFromBackend;
    
    if (mounted) {
      state = AsyncValue.data(finalTier);
      debugPrint("[SubscriptionNotifier] Final unified subscription status is: $finalTier");
    }

    // --- THIS IS THE FIX ---
    // Only update the backend if the unified tier is different from what the backend already has.
    // This check breaks the infinite loop.
    if (finalTier.name != backendSubLevel) {
      debugPrint("[SubscriptionNotifier] Syncing new tier (${finalTier.name}) to backend.");
      await _ref.read(authProvider.notifier).updateUser(
        subscriptionLevel: finalTier.name,
      );
    }
    // --- END OF FIX ---
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    debugPrint("[SubscriptionNotifier] Native purchase info updated. Re-evaluating status.");
    _updateSubscriptionStatus();
  }

  Future<void> purchasePackage(Package package) async {
    if (kIsWeb) return;
    try {
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) != PurchasesErrorCode.purchaseCancelledError) {
        throw Exception("Purchase failed: ${e.message}");
      }
    }
  }

  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    try {
      await Purchases.restorePurchases();
    } on PlatformException catch (e) {
      throw Exception("Failed to restore purchases: ${e.message}");
    }
  }
}