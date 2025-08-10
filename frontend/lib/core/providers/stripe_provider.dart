// frontend/lib/core/providers/stripe_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
// TODO: Import your API client (e.g., Dio service)
// import 'package:your_app/core/api/api_client.dart';

// --- Provider Definition ---

final stripeServiceProvider = Provider<StripeService>((ref) {
  // Pass the ref to the service so it can read other providers, like your API client.
  return StripeService(ref);
});

// --- Stripe Service Class ---

class StripeService {
  final Ref _ref;

  StripeService(this._ref) {
    _initStripe();
  }

  void _initStripe() {
    // TODO: Replace with your actual Stripe publishable key.
    // It's best practice to load this from an environment variable.
    Stripe.publishableKey = 'pk_test_YOUR_STRIPE_PUBLISHABLE_KEY';
    // Add any other Stripe-wide settings here.
  }

  /// Initiates the Stripe Checkout flow for a subscription.
  /// This function orchestrates the entire client-side process.
  Future<void> subscribeToPlan({
    required String planId, // e.g., 'basic_plan', 'premium_plan'
    required Function(String) onDisplayError, // Callback to show errors in the UI
  }) async {
    try {
      // Step 1: Call your backend to create a Stripe Checkout Session.
      // Your backend will create the session and return its client_secret.
      // final apiClient = _ref.read(apiClientProvider);
      // final response = await apiClient.post('/create-stripe-payment-intent', data: {'planId': planId});
      // final clientSecret = response.data['clientSecret'];
      
      // ---- START MOCK BACKEND CALL ----
      // This is a placeholder for your actual backend call.
      print("Calling backend to create Stripe Checkout Session for plan: $planId...");
      await Future.delayed(const Duration(seconds: 1)); // Simulate network latency
      const String clientSecret = "pi_..._secret_..."; // A fake client secret. The real one comes from your backend.
      // ---- END MOCK BACKEND CALL ----


      if (clientSecret == null) {
        throw Exception("Failed to get payment client secret from server.");
      }

      // Step 2: Present the Stripe payment sheet to the user.
      // This will open a web view on desktop for the user to enter payment details.
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Your App Name', // TODO: Change your app name
          // You can also pre-fill customer data if you have it
          // customerId: response.data['customerId'],
          // customerEphemeralKeySecret: response.data['ephemeralKey'],
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      
      // Step 3: Confirmation is handled by webhooks.
      // Your backend will receive a `checkout.session.completed` event from Stripe.
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