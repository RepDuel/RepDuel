// Picks the right implementation per platform.
export 'adapter_io.dart' if (dart.library.html) 'adapter_web.dart';
