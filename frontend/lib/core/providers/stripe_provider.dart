// frontend/lib/core/providers/stripe_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// TODO: Replace 'your_app' with your actual project name from pubspec.yaml
import 'package:repduel/core/config/env.dart';

// TODO: Import your API client (e.g., from a Dio service provider)
// import 'package:repduel/core/api/api_client.dart';

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
    // Add any other Stripe-wide settings here.
  }

  /// Initiates the Stripe Checkout flow for a subscription.
  /// This function orchestrates the entire client-side process.
  Future<void> subscribeToPlan({
    required String planId, // e.g., Env.stripePremiumPlanId
    required Function(String) onDisplayError, // Callback to show errors in the UI
  }) async {
    try {
      // Step 1: Call your backend to create a Stripe Checkout Session.
      // Your backend will create the session and return its client_secret.
      
      // ---- TODO: REPLACE THIS MOCK BACKEND CALL WITH YOUR REAL API CLIENT ----
      // Example of a real call using a hypothetical apiClientProvider:
      // final apiClient = _ref.read(apiClientProvider);
      // final response = await apiClient.post(
      //   '/create-stripe-payment-intent', 
      //   data: {'planId': planId}
      // );
      // final clientSecret = response.data['clientSecret'] as String?;
      
      // This is a placeholder for your actual backend call.
      print("Calling backend to create Stripe Checkout Session for plan: $planId...");
      await Future.delayed(const Duration(seconds: 1)); // Simulate network latency
      // This fake secret will fail. You must get a real one from your backend.
      const String clientSecret = "pi_..._secret_..."; 
      // ---- END MOCK BACKEND CALL ----

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception("Failed to get payment client secret from server.");
      }

      // Step 2: Present the Stripe payment sheet to the user.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: Env.merchantDisplayName,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      
      // Step 3: Confirmation is handled by webhooks.
      // Your backend receives a `checkout.session.completed` event from Stripe.
      // In that webhook handler, you update the user's `subscription_level` in your database.
      // The app will see the change the next time it fetches the user profile.
      print("Payment sheet presented. Awaiting webhook for confirmation.");

    } on StripeException catch (e) {
      print("Stripe Error: ${e.error.localizedMessage}");
      onDisplayError(e.error.localizedMessage ?? "A payment error occurred.");
    } catch (e) {
      print("Generic Error: $e");
      onDisplayError("An unexpected error occurred. Please try again.");
    }
  }
}