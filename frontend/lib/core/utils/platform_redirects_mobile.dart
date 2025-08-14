// frontend/lib/core/utils/platform_redirects_mobile.dart

class PlatformRedirects {
  /// Returns a map containing the correct success/cancel URLs for mobile.
  static Map<String, String> get urls {
    // This MUST be the public, custom domain URL of your live Flutter web app.
    const String liveWebAppUrl = 'https://www.repduel.io';

    return {
      'success_url': '$liveWebAppUrl/payment-success',
      'cancel_url': '$liveWebAppUrl/payment-cancel',
    };
  }
}