// frontend/lib/core/providers/stripe_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint; // For logging
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart'; // Import auth provider
import 'package:repduel/core/utils/platform_redirects_helper.dart';

// Provider for the StripeService.
final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService(ref); // Inject Ref into the service
});

class StripeService {
  final Ref _ref; // Store the Ref

  StripeService(this._ref); // Constructor to receive Ref

  /// Initiates the Stripe checkout session for subscription payment.
  Future<void> subscribeToPlan({
    required Function(String) onDisplayError, // Callback to show errors to the user
  }) async {
    try {
      // Safely get the token from authProvider
      final token = _ref.read(authProvider).valueOrNull?.token;

      if (token == null) {
        // If token is null, user is not authenticated or auth is loading/errored.
        // Throw an exception to be caught by the handler.
        throw Exception("User is not authenticated. Please log in.");
      }

      // Get platform-specific redirect URLs.
      final redirectUrls = PlatformRedirects.urls;

      // Make the POST request to create a Stripe checkout session.
      final response = await http.post(
        Uri.parse('${Env.baseUrl}/api/v1/payments/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Use the safely obtained token
        },
        body: json.encode({
          'price_id': Env.stripePremiumPlanId, // Your Stripe price ID
          'success_url': redirectUrls['success_url'],
          'cancel_url': redirectUrls['cancel_url'],
        }),
      ).timeout(const Duration(seconds: 10)); // Added timeout

      // Check the response status code for success.
      if (response.statusCode != 201) { // Assuming 201 Created for session creation
        final errorData = json.decode(response.body);
        // Throw an exception with a detailed error message.
        throw Exception(
            "Server Error: ${errorData['detail'] ?? response.reasonPhrase ?? 'Unknown error'}");
      }

      // Parse the response JSON to get the checkout URL.
      final responseData = json.decode(response.body);
      final checkoutUrlString = responseData['checkout_url'] as String?;

      if (checkoutUrlString == null || checkoutUrlString.isEmpty) {
        throw Exception("Server did not return a valid checkout URL.");
      }

      // Launch the Stripe checkout URL.
      final checkoutUrl = Uri.parse(checkoutUrlString);
      if (!await canLaunchUrl(checkoutUrl)) {
        throw Exception("Could not prepare to launch the Stripe URL.");
      }

      // Use webOnlyWindowName: '_self' for web to open in the same tab.
      // For mobile, it will open in the browser.
      await launchUrl(
        checkoutUrl,
        webOnlyWindowName: kIsWeb ? '_self' : null, 
      );
    } catch (e) {
      // Use the provided callback to display errors to the user.
      onDisplayError(
          "An unexpected error occurred: ${e.toString().replaceFirst("Exception: ", "")}");
      debugPrint("[StripeService] Error during subscribeToPlan: $e");
    }
  }
}