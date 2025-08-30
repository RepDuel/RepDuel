import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';

/// Provider for accessing the StripeService.
final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService(ref);
});

/// A service for handling Stripe-related operations, like creating checkout sessions.
class StripeService {
  final Ref _ref;

  StripeService(this._ref);

  /// Initiates the Stripe checkout session for a subscription plan.
  Future<void> subscribeToPlan({
    required Function(String) onDisplayError,
  }) async {
    try {
      final token = _ref.read(authProvider).valueOrNull?.token;
      if (token == null) {
        throw Exception("User is not authenticated. Please log in.");
      }

      // --- INDUSTRY STANDARD FIX ---
      // Generate static, absolute URLs for Stripe redirects. This ensures a consistent
      // return path regardless of where the user initiated the payment flow.
      final String baseUrl = Uri.base
          .toString()
          .split('#')
          .first; // Get URL before any hash fragments.
      final String successUrl =
          Uri.parse(baseUrl).resolve('/subscribe/payment-success').toString();
      final String cancelUrl =
          Uri.parse(baseUrl).resolve('/subscribe/payment-cancel').toString();
      // --- END OF FIX ---

      final response = await http
          .post(
            Uri.parse('${Env.baseUrl}/api/v1/payments/create-checkout-session'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'price_id': Env.stripePremiumPlanId,
              'success_url': successUrl, // Use the static success URL.
              'cancel_url': cancelUrl, // Use the static cancel URL.
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw Exception(
            "Server Error: ${errorData['detail'] ?? 'Failed to create session.'}");
      }

      final responseData = json.decode(response.body);
      final checkoutUrlString = responseData['checkout_url'] as String?;

      if (checkoutUrlString == null || checkoutUrlString.isEmpty) {
        throw Exception("Server did not return a valid checkout URL.");
      }

      final checkoutUrl = Uri.parse(checkoutUrlString);
      if (!await canLaunchUrl(checkoutUrl)) {
        throw Exception("Could not prepare to launch the Stripe URL.");
      }

      // On web, '_self' ensures the redirect happens in the same tab.
      // On mobile, this parameter is ignored and the URL opens in an external browser.
      await launchUrl(checkoutUrl, webOnlyWindowName: kIsWeb ? '_self' : null);
    } catch (e) {
      final errorMessage = e.toString().replaceFirst("Exception: ", "");
      onDisplayError("An unexpected error occurred: $errorMessage");
      debugPrint("[StripeService] Error during subscribeToPlan: $e");
    }
  }
}
