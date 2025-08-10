// frontend/lib/core/providers/iap_provider.dart

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// TODO: Replace 'your_app' with your actual project name from pubspec.yaml
import 'package:repduel/core/config/env.dart';

// --- Configuration ---

// TODO: Replace 'premium' with the actual Entitlement ID you set up in RevenueCat.
// This is the identifier for your premium subscription tier.
const String _premiumEntitlementId = 'premium';

// --- Data Models ---

// Defines the subscription tiers in your app.
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
      
      // Initialize Purchases for the correct platform using the key from our Env class.
      if (Platform.isIOS || Platform.isMacOS) {
        await Purchases.configure(PurchasesConfiguration(Env.revenueCatAppleKey));
      } 
      // else if (Platform.isAndroid) {
      //   await Purchases.configure(PurchasesConfiguration(Env.revenueCatGoogleKey));
      // }
      
      // TODO: IMPORTANT! Associate purchases with the logged-in user.
      // This is critical for tying purchases to an account.
      // Uncomment and adapt this code to work with your auth provider.
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
    // Check if the entitlement we defined is active.
    final bool isPremium = customerInfo.entitlements.active[_premiumEntitlementId] != null;

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
    } on PlatformException catch (e) {
      throw Exception("Failed to restore purchases: ${e.message}");
    }
  }
}