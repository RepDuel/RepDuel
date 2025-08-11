// frontend/lib/core/services/share_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

// Import the specific UI widget this service needs.
import '../../features/ranked/screens/result_screen.dart' show ShareableResultCard; 
// Import the new, centralized utility file for rank logic.
import '../../features/ranked/utils/rank_utils.dart'; 
import '../providers/auth_provider.dart';

// A Riverpod provider that creates an instance of our new service
final shareServiceProvider = Provider((ref) => ShareService(ref));

class ShareService {
  final Ref _ref;
  ShareService(this._ref);

  /// Captures a widget and shares it as an image, handling both web and native platforms.
  Future<void> shareResult({
    required BuildContext context, // Needed for InheritedTheme
    required ScreenshotController screenshotController,
    required Map<String, dynamic> scenarioData,
    required Map<String, dynamic> rankData,
    required int finalScore,
  }) async {
    final user = _ref.read(authProvider).user;
    final weightMultiplier = user?.weightMultiplier ?? 1.0;

    try {
      final imageBytes = await screenshotController.captureFromWidget(
        // We wrap the shareable card to ensure it has access to the app's theme
        InheritedTheme.captureAll(
          context,
          Material(
            color: Colors.transparent,
            child: ShareableResultCard(
              username: user?.username ?? 'An Athlete',
              scenarioName: scenarioData['name'] ?? 'Scenario',
              finalScore: (finalScore * weightMultiplier).round(),
              rankName: rankData['current_rank'] ?? 'Unranked',
              // CORRECTED: Call the global getRankColor function from our utility file.
              rankColor: getRankColor(rankData['current_rank'] ?? 'Unranked'),
            ),
          ),
        ),
        delay: Duration.zero,
      );

      final shareText = 'I just hit a new score of ${(finalScore * weightMultiplier).round()} in ${scenarioData['name']} on RepDuel! Can you beat it? #RepDuel';

      // Platform-aware sharing logic
      if (kIsWeb) {
        await Share.shareXFiles(
          [XFile.fromData(imageBytes, name: 'repduel_result.png', mimeType: 'image/png')],
          text: shareText,
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/repduel_result.png';
        await File(path).writeAsBytes(imageBytes);
        await Share.shareXFiles([XFile(path)], text: shareText);
      }
    } catch (e) {
      // Let the UI decide how to show the error by re-throwing it.
      throw Exception('Failed to share result: $e');
    }
  }
}