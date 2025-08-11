// frontend/lib/core/providers/stripe_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:repduel/core/config/env.dart';
import 'package:repduel/core/providers/auth_provider.dart';

// --- Provider Definition ---

final stripeServiceProvider = Provider<StripeService>((ref) {
  // Pass the ref to the service so it can read other providers.
  return StripeService(ref);
});

// --- Stripe Service Class ---

class StripeService {
  final Ref _ref;

  StripeService(this._ref) {
    _initStripe();
  }

  void _initStripe() {
    // Initialize Stripe using the configuration from our Env class.
    Stripe.publishableKey = Env.stripePublishableKey;
  }

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
          // TODO: Replace these with your actual production URLs when you deploy.
          'success_url': 'http://localhost:3000/success', // A page in your app for success
          'cancel_url': 'http://localhost:3000/cancel',   // A page for cancellation
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

      // Step 4: Redirect the user to the Stripe Checkout page.
      final checkoutUrl = Uri.parse(checkoutUrlString);
      if (await canLaunchUrl(checkoutUrl)) {
        // This will open the URL in the user's browser.
        await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("Could not launch Stripe checkout URL.");
      }
      
      // After this, the process is out of the app's hands.
      // Stripe handles the payment, and on success, sends a webhook to your backend.
      // Your backend webhook handler is responsible for updating the user's subscription_level.

    } on StripeException catch (e) {
      // This might catch client-side Stripe errors, though less likely with this flow.
      print("Stripe Error: ${e.error.localizedMessage}");
      onDisplayError(e.error.localizedMessage ?? "A payment error occurred.");
    } catch (e) {
      print("Generic Error: $e");
      onDisplayError("An unexpected error occurred: ${e.toString()}");
    }
  }
}
