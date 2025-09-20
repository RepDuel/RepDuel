// frontend/lib/features/routines/models/summary_screen_args.dart

import 'summary_personal_best.dart';

class SummaryScreenArgs {
  final double totalVolumeKg;
  final List<SummaryPersonalBest> personalBests;

  const SummaryScreenArgs({
    required this.totalVolumeKg,
    required this.personalBests,
  });
}
