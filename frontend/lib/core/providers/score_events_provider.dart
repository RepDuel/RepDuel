// frontend/lib/core/providers/score_events_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increment this whenever any score changes anywhere in the app.
/// Listeners (e.g., NormalScreen) will invalidate their local caches.
final scoreEventsProvider = StateProvider<int>((ref) => 0);
