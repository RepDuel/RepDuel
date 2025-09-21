// frontend/lib/features/profile/providers/level_progress_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/level_progress.dart';
import '../../../core/providers/api_providers.dart';

final levelProgressProvider = FutureProvider.autoDispose<LevelProgress>((ref) async {
  final api = ref.watch(levelApiProvider);
  return api.getMyLevelProgress();
});
