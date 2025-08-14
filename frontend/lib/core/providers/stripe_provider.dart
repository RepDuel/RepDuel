// frontend/lib/core/providers/stripe_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// This conditional import provides access to the browser's 'window' object on web,
// and is ignored on mobile platforms to prevent compilation errors.
import 'dart:html' if (dart.library.io) 'dart:io' as html;

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';

final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService(ref);
});

/// A service class to handle all Stripe-related payment operations.
class StripeService {
  final Ref _ref;
  StripeService(this._ref);

  /// Initiates the Stripe Checkout flow for a subscription plan.
  ///
  /// This method orchestrates the client-side process by:
  /// 1. Dynamically determining the correct success/cancel URLs based on the platform.
  /// 2. Calling the backend to create a secure Stripe Checkout Session.
  /// 3. Redirecting the user to the Stripe-hosted payment page.
  Future<void> subscribeToPlan({
    required Function(String) onDisplayError,
  }) async {
    try {
      final token = _ref.read(authProvider).token;
      if (token == null) {
        throw Exception("User is not authenticated. Please log in.");
      }

      // Dynamically construct redirect URLs to handle varying localhost ports in dev
      // and provide the correct production URLs when deployed.
      String successUrl;
      String cancelUrl;

      if (kIsWeb) {
        final String origin = html.window.location.origin;
        successUrl = '$origin/payment-success';
        cancelUrl = '$origin/payment-cancel';
      } else {
        // TODO(mobile): Replace with a deep link scheme (e.g., 'repduel://payment-success') for native builds.
        successUrl = 'https://app.repduel.com/payment-success';
        cancelUrl = 'https://app.repduel.com/payment-cancel';
      }
      
      final response = await http.post(
        Uri.parse('${Env.baseUrl}/api/v1/payments/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'price_id': Env.stripePremiumPlanId,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        }),
      );

      if (response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw Exception("Server Error: ${errorData['detail'] ?? response.reasonPhrase}");
      }
      
      final responseData = json.decode(response.body);
      final checkoutUrlString = responseData['checkout_url'] as String?;

      if (checkoutUrlString == null || checkoutUrlString.isEmpty) {
        throw Exception("Server did not return a valid checkout URL.");
      }

      final checkoutUrl = Uri.parse(checkoutUrlString);
      if (!await canLaunchUrl(checkoutUrl)) {
        throw Exception("Could not prepare to launch Stripe URL.");
      }
      
      await launchUrl(
        checkoutUrl,
        webOnlyWindowName: '_self',
      );

    } on StripeException catch (e) {
      onDisplayError(e.error.localizedMessage ?? "A Stripe payment error occurred.");
    } catch (e) {
      onDisplayError("An unexpected error occurred: ${e.toString()}");
    }
  }
}