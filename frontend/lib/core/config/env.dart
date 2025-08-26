// frontend/lib/core/config/env.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Private constructor
  Env._();

  // --- Getter for baseUrl ---
  static String get baseUrl {
    // First, try to get from --dart-define (compile-time)
    const fromEnv = String.fromEnvironment('BACKEND_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    // If not found, fall back to .env file (runtime)
    return dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';
  }

  // --- Getter for revenueCatAppleKey ---
  static String get revenueCatAppleKey {
    const fromEnv = String.fromEnvironment('REVENUE_CAT_APPLE_KEY');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['REVENUE_CAT_APPLE_KEY'] ?? '';
  }

  // --- Getter for stripePublishableKey ---
  static String get stripePublishableKey {
    const fromEnv = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  }
  
  // --- Getter for merchantDisplayName ---
  static String get merchantDisplayName {
    const fromEnv = String.fromEnvironment('MERCHANT_DISPLAY_NAME');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['MERCHANT_DISPLAY_NAME'] ?? 'RepDuel';
  }
  
  // --- Getter for stripePremiumPlanId ---
  static String get stripePremiumPlanId {
    const fromEnv = String.fromEnvironment('STRIPE_PREMIUM_PLAN_ID');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_PREMIUM_PLAN_ID'] ?? '';
  }

  // --- Getter for stripeSuccessUrl ---
  static String get stripeSuccessUrl {
    const fromEnv = String.fromEnvironment('STRIPE_SUCCESS_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_SUCCESS_URL'] ?? '';
  }

  // --- Getter for stripeCancelUrl ---
  static String get stripeCancelUrl {
    const fromEnv = String.fromEnvironment('STRIPE_CANCEL_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return dotenv.env['STRIPE_CANCEL_URL'] ?? '';
  }
}