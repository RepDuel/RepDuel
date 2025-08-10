// frontend/lib/core/providers/iap_provider.dart

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// TODO: Replace with your actual RevenueCat API key for Apple.
// It's best practice to load this from an environment variable.
const String _appleApiKey = "appl_YOUR_REVENUE_CAT_APPLE_KEY"; 

// --- Data Models ---

// Defines the subscription tiers in your app.
// These should correspond to Entitlements you set up in RevenueCat.
enum SubscriptionTier {
  free,
  premium,
}

// --- Provider Definitions ---

// Manages the user's current subscription status.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<SubscriptionTier>>(
  (ref) => SubscriptionNotifier(ref),
);

// Fetches the available subscription offerings from RevenueCat.
final offeringsProvider = FutureProvider<Offerings>((ref) async {
  try {
    return await Purchases.getOfferings();
  } on PlatformException catch (e) {
    throw Exception("Failed to fetch offerings: ${e.message}");
  }
});


// --- State Notifier ---

class SubscriptionNotifier extends StateNotifier<AsyncValue<SubscriptionTier>> {
  final Ref _ref;
  StreamSubscription<CustomerInfo>? _customerInfoSubscription;

  SubscriptionNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
    // Listen for real-time updates to customer info.
    _customerInfoSubscription =
        Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
  }

  @override
  void dispose() {
    _customerInfoSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    state = const AsyncValue.loading();
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      
      // IMPORTANT: Initialize Purchases for the correct platform.
      if (Platform.isIOS || Platform.isMacOS) {
        await Purchases.configure(PurchasesConfiguration(_appleApiKey));
      } 
      // else if (Platform.isAndroid) {
      //   await Purchases.configure(PurchasesConfiguration(_googleApiKey));
      // }
      
      // IMPORTANT: Associate purchases with the logged-in user.
      // This assumes you have an authProvider that holds the user state.
      // final userId = _ref.read(authProvider).user?.id;
      // if (userId != null) {
      //   await Purchases.logIn(userId);
      // }

      final customerInfo = await Purchases.getCustomerInfo();
      _onCustomerInfoUpdated(customerInfo);

    } on PlatformException catch (e, s) {
      state = AsyncValue.error("Failed to initialize purchases: ${e.message}", s);
    }
  }

  // This is the core logic that maps a RevenueCat entitlement to your app's tier.
  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    // TODO: Replace 'premium' with your actual Entitlement ID from RevenueCat.
    final bool isPremium = customerInfo.entitlements.active['premium'] != null;

    if (isPremium) {
      state = const AsyncValue.data(SubscriptionTier.premium);
    } else {
      state = const AsyncValue.data(SubscriptionTier.free);
    }
  }

  // Initiates a purchase for a given subscription package.
  Future<void> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _onCustomerInfoUpdated(customerInfo); // Update state immediately
      // Your backend will receive a webhook from RevenueCat to verify and update the user's status.
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        // Don't throw an error if the user just cancelled.
        throw Exception("Purchase failed: ${e.message}");
      }
    }
  }

  // Restores a user's previous purchases.
  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _onCustomerInfoUpdated(customerInfo);
      // Let the user know if their purchases were restored.
    } on PlatformException catch (e) {
      throw Exception("Failed to restore purchases: ${e.message}");
    }
  }
}