// frontend/lib/core/providers/iap_provider.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart'; // <-- ADDED

// --- Configuration ---
const String _goldEntitlementId = 'gold';
const String _platinumEntitlementId = 'platinum';

// --- Data Models ---
enum SubscriptionTier {
  free,
  gold,
  platinum,
}

// --- Provider Definitions ---
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<SubscriptionTier>>(
  (ref) => SubscriptionNotifier(ref),
);

final offeringsProvider = FutureProvider<Offerings>((ref) async {
  if (kIsWeb) {
    return Offerings(<String, Offering>{}); 
  }
  try {
    return await Purchases.getOfferings();
  } on PlatformException catch (e) {
    throw Exception("Failed to fetch offerings: ${e.message}");
  }
});

// --- State Notifier ---
class SubscriptionNotifier extends StateNotifier<AsyncValue<SubscriptionTier>> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();

    // Listen for native purchase updates from Apple/Google.
    if (!kIsWeb) {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    
    // --- FIX: Listen for backend user data changes from Stripe/Web ---
    // This is the key change. When AuthProvider refreshes the user, this
    // provider will also re-evaluate the subscription status.
    _ref.listen(authProvider, (_, __) {
      print("[Subscription] Auth state changed, re-evaluating subscription status.");
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

  /// Initializes the necessary purchase services and performs the first status check.
  Future<void> _init() async {
    state = const AsyncValue.loading();
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
        await Purchases.configure(PurchasesConfiguration(Env.revenueCatAppleKey));
      }
      // Run the initial unified status check.
      await _updateSubscriptionStatus();
    } on PlatformException catch (e, s) {
      state = AsyncValue.error("Failed to initialize purchases: ${e.message}", s);
    } catch (e, s) {
      state = AsyncValue.error("An unexpected error occurred during init: $e", s);
    }
  }

  /// The single source of truth for the user's subscription tier.
  ///
  /// This method checks both the backend (for Stripe/web) and native entitlements
  /// (for Apple/Google) and sets the state to the highest available tier.
  Future<void> _updateSubscriptionStatus() async {
    // 1. Get status from our backend via AuthProvider
    final user = _ref.read(authProvider).user;
    final backendSubLevel = user?.subscriptionLevel ?? 'free';

    SubscriptionTier tierFromBackend = SubscriptionTier.free;
    if (backendSubLevel == 'gold') {
      tierFromBackend = SubscriptionTier.gold;
    } else if (backendSubLevel == 'platinum') {
      tierFromBackend = SubscriptionTier.platinum;
    }

    // 2. Get status from native entitlements (Apple/Google)
    SubscriptionTier tierFromNative = SubscriptionTier.free;
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        final isPlatinum = customerInfo.entitlements.active[_platinumEntitlementId] != null;
        final isGold = customerInfo.entitlements.active[_goldEntitlementId] != null;
        
        if (isPlatinum) {
          tierFromNative = SubscriptionTier.platinum;
        } else if (isGold) {
          tierFromNative = SubscriptionTier.gold;
        }
      } catch (e) {
        print("[Subscription] Could not get native customer info: $e. Relying on backend status.");
      }
    }
    
    // 3. Determine the highest tier to be the final status.
    // The `.index` of an enum gives its order (free=0, gold=1, platinum=2).
    final finalTier = tierFromNative.index > tierFromBackend.index ? tierFromNative : tierFromBackend;
    
    // 4. Update the state with the unified result.
    if (mounted) {
      state = AsyncValue.data(finalTier);
      print("[Subscription] Final unified subscription status is: $finalTier");
    }
  }

  /// This listener is triggered by native events and now delegates to the unified status checker.
  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    print("[Subscription] Native purchase info updated, triggering status re-evaluation.");
    _updateSubscriptionStatus();
  }

  Future<void> purchasePackage(Package package) async {
    if (kIsWeb) return;
    try {
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
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