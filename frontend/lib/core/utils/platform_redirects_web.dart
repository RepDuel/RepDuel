// frontend/lib/core/utils/platform_redirects_web.dart

class PlatformRedirects {
  static Map<String, String> get urls {
    final String origin = Uri.base.toString();
    return {
      'success_url': '$origin/payment-success',
      'cancel_url': '$origin/payment-cancel',
    };
  }
}
