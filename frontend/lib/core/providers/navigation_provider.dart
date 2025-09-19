// frontend/lib/core/providers/navigation_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls visibility of the main bottom navigation bar.
final bottomNavVisibilityProvider = StateProvider<bool>((ref) => true);
