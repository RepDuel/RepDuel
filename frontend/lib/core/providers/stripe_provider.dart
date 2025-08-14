import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';
// IMPORT THE NEW HELPER, NOT THE SPECIFIC IMPLEMENTATIONS
import 'package:repduel/core/utils/platform_redirects_helper.dart';

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
      final token = _ref.read(authProvider).token;
      if (token == null) {
        throw Exception("User is not authenticated. Please log in.");
      }

      final redirectUrls = PlatformRedirects.urls;

      final response = await http.post(
        Uri.parse('${Env.baseUrl}/api/v1/payments/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'price_id': Env.stripePremiumPlanId,
          'success_url': redirectUrls['success_url'],
          'cancel_url': redirectUrls['cancel_url'],
        }),
      );

      if (response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw Exception(
            "Server Error: ${errorData['detail'] ?? response.reasonPhrase}");
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

      await launchUrl(
        checkoutUrl,
        webOnlyWindowName: '_self',
      );
    } catch (e) {
      onDisplayError(
          "An unexpected error occurred: ${e.toString().replaceFirst("Exception: ", "")}");
    }
  }
}