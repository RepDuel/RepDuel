// This file is ONLY for web platforms.
import 'dart:html';

class PlatformRedirects {
  /// Returns a map containing the correct success/cancel URLs for web.
  static Map<String, String> get urls {
    final String origin = window.location.origin;
    return {
      'success_url': '$origin/payment-success',
      'cancel_url': '$origin/payment-cancel',
    };
  }
}
