// This file conditionally exports the correct implementation.
// The default is mobile. If 'dart.library.html' exists, it uses the web version.

export 'platform_redirects_mobile.dart'
    if (dart.library.html) 'platform_redirects_web.dart';