// frontend/lib/core/providers/iap_provider.dart

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode; // <-- FIX: Ensure kDebugMode is imported
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:repduel/core/config/env.dart';

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
    // FIX: The Offerings constructor takes a single Map<String, Offering>.
    // For web, we can return an empty map.
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
    if (!kIsWeb) {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      state = const AsyncValue.data(SubscriptionTier.free);
      return;
    }

    state = const AsyncValue.loading();
    try {
      // FIX: kDebugMode is now correctly referenced as a global constant.
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      
      if (Platform.isIOS || Platform.isMacOS) {
        await Purchases.configure(PurchasesConfiguration(Env.revenueCatAppleKey));
      } 
      
      final customerInfo = await Purchases.getCustomerInfo();
      _onCustomerInfoUpdated(customerInfo);

    } on PlatformException catch (e, s) {
      state = AsyncValue.error("Failed to initialize purchases: ${e.message}", s);
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    final bool isPlatinum = customerInfo.entitlements.active[_platinumEntitlementId] != null;
    // FIX: Corrected typo from 'entitleaments' to 'entitlements'.
    final bool isGold = customerInfo.entitlements.active[_goldEntitlementId] != null;

    if (isPlatinum) {
      state = const AsyncValue.data(SubscriptionTier.platinum);
    } else if (isGold) {
      state = const AsyncValue.data(SubscriptionTier.gold);
    } else {
      state = const AsyncValue.data(SubscriptionTier.free);
    }
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