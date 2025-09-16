// frontend/lib/core/config/env.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('BACKEND_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';
  }

  static String get revenueCatAppleKey {
    const fromEnv = String.fromEnvironment('REVENUE_CAT_APPLE_KEY');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['REVENUE_CAT_APPLE_KEY'] ?? '';
  }

  static String get stripePublishableKey {
    const fromEnv = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  }

  static String get merchantDisplayName {
    const fromEnv = String.fromEnvironment('MERCHANT_DISPLAY_NAME');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['MERCHANT_DISPLAY_NAME'] ?? 'RepDuel';
  }

  // Public base URL for shareable links and deep links
  // Example: https://repduel.com
  static String get publicBaseUrl {
    const fromEnv = String.fromEnvironment('PUBLIC_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final fromDot = dotenv.env['PUBLIC_BASE_URL'];
    if (fromDot != null && fromDot.isNotEmpty) {
      return fromDot;
    }
    return 'https://repduel.com';
  }

  static String get stripePremiumPlanId {
    const fromEnv = String.fromEnvironment('STRIPE_PREMIUM_PLAN_ID');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_PREMIUM_PLAN_ID'] ?? '';
  }

  static String get stripeSuccessUrl {
    const fromEnv = String.fromEnvironment('STRIPE_SUCCESS_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_SUCCESS_URL'] ?? '';
  }

  static String get stripeCancelUrl {
    const fromEnv = String.fromEnvironment('STRIPE_CANCEL_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_CANCEL_URL'] ?? '';
  }
}
