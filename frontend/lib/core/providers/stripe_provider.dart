// frontend/lib/core/services/stripe_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:repduel/core/api/api_urls.dart';
import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';

final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService(ref);
});

class StripeService {
  final Ref _ref;

  StripeService(this._ref);

  Future<void> subscribeToPlan({
    required Function(String) onDisplayError,
  }) async {
    try {
      final token = _ref.read(authProvider).valueOrNull?.token;
      if (token == null) {
        throw Exception("User is not authenticated. Please log in.");
      }

      final String baseUrl = Uri.base.toString().split('#').first;
      final String successUrl =
          Uri.parse(baseUrl).resolve('/payment-success').toString();
      final String cancelUrl =
          Uri.parse(baseUrl).resolve('/payment-cancel').toString();

      final response = await http
          .post(
            apiUri('/payments/create-checkout-session'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'price_id': Env.stripePremiumPlanId,
              'success_url': successUrl,
              'cancel_url': cancelUrl,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw Exception(
          "Server Error: ${errorData['detail'] ?? 'Failed to create session.'}",
        );
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

      await launchUrl(checkoutUrl, webOnlyWindowName: kIsWeb ? '_self' : null);
    } catch (e) {
      final errorMessage = e.toString().replaceFirst("Exception: ", "");
      onDisplayError("An unexpected error occurred: $errorMessage");
      debugPrint("[StripeService] Error during subscribeToPlan: $e");
    }
  }
}
