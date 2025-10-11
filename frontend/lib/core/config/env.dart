import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String envVar(
  String key, {
  String defaultValue = '',
}) {
  final fromDefine = _dartDefineFor(key);
  if (fromDefine.isNotEmpty) {
    return fromDefine;
  }

  if (dotenv.isInitialized) {
    final fromDotenv = dotenv.maybeGet(key);
    if (fromDotenv != null && fromDotenv.isNotEmpty) {
      return fromDotenv;
    }
  }

  return defaultValue;
}

String _dartDefineFor(String key) {
  switch (key) {
    case 'BACKEND_URL':
      return const String.fromEnvironment('BACKEND_URL');
    case 'PUBLIC_BASE_URL':
      return const String.fromEnvironment('PUBLIC_BASE_URL');
    case 'MERCHANT_DISPLAY_NAME':
      return const String.fromEnvironment('MERCHANT_DISPLAY_NAME');
    case 'STRIPE_PUBLISHABLE_KEY':
      return const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    case 'STRIPE_PREMIUM_PLAN_ID':
      return const String.fromEnvironment('STRIPE_PREMIUM_PLAN_ID');
    case 'STRIPE_SUCCESS_URL':
      return const String.fromEnvironment('STRIPE_SUCCESS_URL');
    case 'STRIPE_CANCEL_URL':
      return const String.fromEnvironment('STRIPE_CANCEL_URL');
    case 'REVENUE_CAT_APPLE_KEY':
      return const String.fromEnvironment('REVENUE_CAT_APPLE_KEY');
    case 'PAYMENTS_ENABLED':
      return const String.fromEnvironment('PAYMENTS_ENABLED');
  }

  return '';
}

String _defaultBackendUrl() {
  if (kIsWeb) {
    final uri = Uri.base;
    final host = uri.host.toLowerCase();
    final isLoopbackHost =
        host.isEmpty || host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
    final isPrivateNetwork = RegExp(r'^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)')
        .hasMatch(host);
    final isLocalHost = isLoopbackHost || host.endsWith('.local');
    if (!(isLocalHost || isPrivateNetwork)) {
      return 'https://api.repduel.com';
    }
  }

  return 'http://127.0.0.1:8000';
}

bool _envFlag(String key, {bool defaultValue = false}) {
  final raw = envVar(
    key,
    defaultValue: defaultValue ? 'true' : 'false',
  ).trim();

  switch (raw.toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    default:
      return false;
  }
}

String _resolveBackendUrl() {
  final value = envVar('BACKEND_URL');
  if (value.isNotEmpty) {
    return value;
  }

  return _defaultBackendUrl();
}

class Env {
  Env._();

  static final backendUrl = _resolveBackendUrl();

  static final publicBaseUrl =
      envVar('PUBLIC_BASE_URL', defaultValue: 'http://localhost:5000');

  static final merchantDisplayName =
      envVar('MERCHANT_DISPLAY_NAME', defaultValue: 'RepDuel');

  static final stripePublishableKey = envVar('STRIPE_PUBLISHABLE_KEY');

  static final stripePremiumPlanId = envVar('STRIPE_PREMIUM_PLAN_ID');

  static final stripeSuccessUrl = envVar('STRIPE_SUCCESS_URL');

  static final stripeCancelUrl = envVar('STRIPE_CANCEL_URL');

  static final revenueCatAppleKey = envVar('REVENUE_CAT_APPLE_KEY');

  static final paymentsEnabled = _envFlag('PAYMENTS_ENABLED');
}
