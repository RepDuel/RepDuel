// frontend/lib/core/utils/platform_redirects_web.dart

// This file is ONLY for web platforms.
class PlatformRedirects {
  /// Returns a map containing the correct success/cancel URLs for web.
  static Map<String, String> get urls {
    final String origin =
        Uri.base.toString(); // `Uri.base` gives the current web origin.
    return {
      'success_url': '$origin/payment-success',
      'cancel_url': '$origin/payment-cancel',
    };
  }
}
