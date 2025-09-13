// frontend/lib/core/utils/platform_redirects_helper.dart

export 'platform_redirects_mobile.dart'
    if (dart.library.html) 'platform_redirects_web.dart';
