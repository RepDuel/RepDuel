import 'package:repduel/core/config/env.dart';

class PlatformRedirects {
  static Map<String, String> get urls {
    return {
      'success_url': Env.stripeSuccessUrl,
      'cancel_url': Env.stripeCancelUrl,
    };
  }
}