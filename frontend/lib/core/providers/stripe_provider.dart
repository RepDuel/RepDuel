// frontend/lib/core/providers/stripe_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart'; // This import is still needed for StripeException
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';

// --- Provider Definition ---

final stripeServiceProvider = Provider<StripeService>((ref) {
  // Pass the ref to the service so it can read other providers.
  return StripeService(ref);
});

// --- Stripe Service Class (Simplified) ---

class StripeService {
  final Ref _ref;

  // --- FIX: REMOVED THE CONSTRUCTOR AND INITIALIZATION ---
  // The _initStripe() method has been removed because initialization
  // is now correctly handled in main.dart before the app runs.
  StripeService(this._ref);
  // --- END FIX ---


  /// Initiates the Stripe Checkout flow for a subscription.
  /// This function orchestrates the entire client-side process.
  Future<void> subscribeToPlan({
    required Function(String) onDisplayError, // Callback to show errors in the UI
  }) async {
    try {
      // Step 1: Get the currently authenticated user's token.
      final token = _ref.read(authProvider).token;
      if (token == null) {
        throw Exception("User is not authenticated. Please log in.");
      }

      // Step 2: Call your backend to create a Stripe Checkout Session.
      print("Calling backend to create Stripe Checkout Session...");
      
      final response = await http.post(
        Uri.parse('${Env.baseUrl}/api/v1/payments/create-checkout-session'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          // Pass the Price ID for the plan the user is subscribing to.
          'price_id': Env.stripePremiumPlanId, // From your .env file
          
          // These are the URLs Stripe will redirect to.
          'success_url': Env.stripeSuccessUrl,
          'cancel_url': Env.stripeCancelUrl,
        }),
      );

      // Step 3: Handle the backend response.
      if (response.statusCode != 201) { // We expect a 201 Created status
        final errorData = json.decode(response.body);
        throw Exception("Failed to create checkout session: ${errorData['detail'] ?? response.reasonPhrase}");
      }
      
      final responseData = json.decode(response.body);
      final checkoutUrlString = responseData['checkout_url'] as String?;

      if (checkoutUrlString == null || checkoutUrlString.isEmpty) {
        throw Exception("Server did not return a valid checkout URL.");
      }

      // This logic remains correct for launching the URL.
      final checkoutUrl = Uri.parse(checkoutUrlString);
      
      if (!await canLaunchUrl(checkoutUrl)) {
        throw Exception("Could not prepare to launch Stripe URL.");
      }
      
      // On web, `webOnlyWindowName: '_self'` ensures it opens in the SAME tab.
      // On mobile, this parameter is ignored and it opens the external browser correctly.
      await launchUrl(
        checkoutUrl,
        webOnlyWindowName: '_self',
      );
      
      // After this, the process is out of the app's hands.

    } on StripeException catch (e) {
      print("Stripe Error: ${e.error.localizedMessage}");
      onDisplayError(e.error.localizedMessage ?? "A payment error occurred.");
    } catch (e) {
      print("Generic Error: $e");
      onDisplayError("An unexpected error occurred: ${e.toString()}");
    }
  }
}