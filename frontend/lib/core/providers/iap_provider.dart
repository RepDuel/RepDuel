// frontend/lib/core/providers/iap_provider.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';

const String _goldEntitlementId = 'gold';
const String _platinumEntitlementId = 'platinum';

enum SubscriptionTier { free, gold, platinum }

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<SubscriptionTier>>(
  (ref) => SubscriptionNotifier(ref),
);

final offeringsProvider = FutureProvider<Offerings>((ref) async {
  if (kIsWeb) return const Offerings(<String, Offering>{});
  try {
    return await Purchases.getOfferings();
  } on PlatformException catch (e) {
    debugPrint("[iap_provider] Failed to fetch offerings: ${e.message}");
    throw Exception("Failed to fetch offerings: ${e.message}");
  }
});

class SubscriptionNotifier extends StateNotifier<AsyncValue<SubscriptionTier>> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    state = const AsyncValue.loading();
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        await Purchases.setLogLevel(
            kDebugMode ? LogLevel.debug : LogLevel.info);
        await Purchases.configure(
            PurchasesConfiguration(Env.revenueCatAppleKey));
        Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      }

      _ref.listen<AsyncValue<AuthState>>(authProvider, (_, next) {
        final user = next.valueOrNull?.user;
        if (user != null) {
          debugPrint(
              "[SubscriptionNotifier] User logged in. Identifying with RevenueCat as ${user.id}.");
          Purchases.logIn(user.id);
          _updateSubscriptionStatus();
        } else {
          debugPrint(
              "[SubscriptionNotifier] User logged out. Resetting RevenueCat identity.");
          Purchases.logOut();
          state = const AsyncValue.data(SubscriptionTier.free);
        }
      }, fireImmediately: true);
    } on PlatformException catch (e, s) {
      state =
          AsyncValue.error("Failed to initialize purchases: ${e.message}", s);
    } catch (e, s) {
      state =
          AsyncValue.error("An unexpected error occurred during init: $e", s);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }

  Future<void> _updateSubscriptionStatus() async {
    if (kIsWeb) {
      final user = _ref.read(authProvider).valueOrNull?.user;
      final backendSubLevel = user?.subscriptionLevel ?? 'free';
      final tier = SubscriptionTier.values.byName(backendSubLevel);
      if (mounted) state = AsyncValue.data(tier);
      return;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      SubscriptionTier tier = SubscriptionTier.free;
      if (customerInfo.entitlements.active
          .containsKey(_platinumEntitlementId)) {
        tier = SubscriptionTier.platinum;
      } else if (customerInfo.entitlements.active
          .containsKey(_goldEntitlementId)) {
        tier = SubscriptionTier.gold;
      }

      if (mounted) {
        state = AsyncValue.data(tier);
        debugPrint(
            "[SubscriptionNotifier] Native subscription status updated to: $tier");
      }
    } catch (e) {
      debugPrint(
          "[SubscriptionNotifier] Could not get native customer info: $e.");
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) {
    debugPrint(
        "[SubscriptionNotifier] Native purchase info updated via listener. Re-evaluating status.");
    _updateSubscriptionStatus();
  }

  Future<void> purchasePackage(Package package) async {
    if (kIsWeb) return;
    try {
      await Purchases.purchasePackage(package);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.purchaseCancelledError) {
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
