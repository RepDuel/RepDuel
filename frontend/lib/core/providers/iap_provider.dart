// frontend/lib/core/providers/iap_provider.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint; // Import debugPrint
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart'; // Import auth provider

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
  // Avoid RevenueCat calls on web or if not configured.
  if (kIsWeb) {
    // Return an empty Offerings object for web.
    return Offerings(<String, Offering>{}); 
  }
  try {
    return await Purchases.getOfferings();
  } on PlatformException catch (e) {
    // Log the error and rethrow as an Exception for AsyncValue to catch.
    debugPrint("[iap_provider] Failed to fetch offerings: ${e.message}");
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
    
    // Listen for changes in the auth state. When auth state updates,
    // re-evaluate the subscription status based on the new user data.
    _ref.listen(authProvider, (_, __) {
      debugPrint("[SubscriptionNotifier] Auth state changed, re-evaluating subscription status.");
      _updateSubscriptionStatus();
    });
  }

  @override
  void dispose() {
    // Remove the listener to prevent memory leaks.
    if (!kIsWeb) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }

  /// Initializes RevenueCat and performs the initial subscription status check.
  Future<void> _init() async {
    // Set state to loading during initialization.
    state = const AsyncValue.loading();
    try {
      // Configure RevenueCat only for iOS/macOS platforms.
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        // Set log level based on debug mode for better visibility during development.
        await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
        // Configure with your RevenueCat API key from environment variables.
        await Purchases.configure(PurchasesConfiguration(Env.revenueCatAppleKey));
        debugPrint("[SubscriptionNotifier] RevenueCat configured for iOS.");
      } else {
        debugPrint("[SubscriptionNotifier] Not configuring RevenueCat for web or Android.");
      }
      // Perform the initial update of the subscription status.
      await _updateSubscriptionStatus();
    } on PlatformException catch (e, s) {
      // Handle errors during initialization.
      state = AsyncValue.error("Failed to initialize purchases: ${e.message}", s);
      debugPrint("[SubscriptionNotifier] Initialization PlatformException: ${e.message}");
    } catch (e, s) {
      // Handle any other unexpected errors during initialization.
      state = AsyncValue.error("An unexpected error occurred during init: $e", s);
      debugPrint("[SubscriptionNotifier] Initialization error: $e");
    }
  }

  /// Determines the user's current subscription tier by checking both backend
  /// and native entitlement data. It prioritizes the higher tier.
  Future<void> _updateSubscriptionStatus() async {
    // 1. Get status from our backend (via AuthProvider's user data).
    // Safely access user data from authProvider's AsyncValue.
    final user = _ref.read(authProvider).valueOrNull?.user;
    // Default to 'free' if user data or subscriptionLevel is missing.
    final backendSubLevel = user?.subscriptionLevel ?? 'free';

    SubscriptionTier tierFromBackend = SubscriptionTier.free;
    if (backendSubLevel == 'gold') {
      tierFromBackend = SubscriptionTier.gold;
    } else if (backendSubLevel == 'platinum') {
      tierFromBackend = SubscriptionTier.platinum;
    }
    debugPrint("[SubscriptionNotifier] Backend subscription tier: $tierFromBackend");

    // 2. Get status from native entitlements (Apple/Google).
    // This part is only relevant for iOS/macOS.
    SubscriptionTier tierFromNative = SubscriptionTier.free;
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        // Fetch customer info from RevenueCat.
        final customerInfo = await Purchases.getCustomerInfo();
        // Check for active entitlements.
        final isPlatinum = customerInfo.entitlements.active[_platinumEntitlementId] != null;
        final isGold = customerInfo.entitlements.active[_goldEntitlementId] != null;
        
        if (isPlatinum) {
          tierFromNative = SubscriptionTier.platinum;
        } else if (isGold) {
          tierFromNative = SubscriptionTier.gold;
        }
        debugPrint("[SubscriptionNotifier] Native subscription tier: $tierFromNative");
      } catch (e) {
        // Log if native info retrieval fails, but don't block the process.
        print("[SubscriptionNotifier] Could not get native customer info: $e. Relying on backend status.");
      }
    }
    
    // 3. Determine the highest tier to be the final status.
    // Enum indices provide a natural order: free=0, gold=1, platinum=2.
    final finalTier = tierFromNative.index > tierFromBackend.index ? tierFromNative : tierFromBackend;
    
    // 4. Update the state with the unified result.
    // Ensure the widget is still mounted before updating the state.
    if (mounted) {
      state = AsyncValue.data(finalTier);
      debugPrint("[SubscriptionNotifier] Final unified subscription status is: $finalTier");
    }
  }

  /// Listener for native purchase updates (from RevenueCat SDK).
  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    debugPrint("[SubscriptionNotifier] Native purchase info updated. Re-evaluating status.");
    // When native updates occur, re-run the unified status check.
    _updateSubscriptionStatus();
  }

  /// Initiates the purchase flow for a given package.
  Future<void> purchasePackage(Package package) async {
    if (kIsWeb) {
      debugPrint("[SubscriptionNotifier] Cannot purchase on web.");
      return; // Do not attempt purchases on the web via RevenueCat SDK.
    }
    try {
      await Purchases.purchasePackage(package);
      // Purchase successful; the listener (_onCustomerInfoUpdated) will handle status update.
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      // Don't throw an error if the purchase was cancelled by the user.
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("[SubscriptionNotifier] Purchase failed: ${e.message}");
        throw Exception("Purchase failed: ${e.message}");
      } else {
        debugPrint("[SubscriptionNotifier] Purchase cancelled by user.");
      }
    } catch (e) {
      // Catch any other unexpected errors during purchase.
      debugPrint("[SubscriptionNotifier] Unexpected error during purchase: $e");
      throw Exception("An unexpected error occurred during purchase.");
    }
  }

  /// Restores purchases for the user.
  Future<void> restorePurchases() async {
    if (kIsWeb) {
      debugPrint("[SubscriptionNotifier] Cannot restore purchases on web.");
      return; // Do not attempt restores on the web.
    }
    try {
      await Purchases.restorePurchases();
      // Restoration successful; the listener (_onCustomerInfoUpdated) will handle status update.
    } on PlatformException catch (e) {
      debugPrint("[SubscriptionNotifier] Failed to restore purchases: ${e.message}");
      throw Exception("Failed to restore purchases: ${e.message}");
    } catch (e) {
      // Catch any other unexpected errors during restoration.
      debugPrint("[SubscriptionNotifier] Unexpected error during restore: $e");
      throw Exception("An unexpected error occurred during restore.");
    }
  }
}