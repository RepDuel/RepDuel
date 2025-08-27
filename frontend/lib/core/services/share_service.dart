// frontend/lib/core/services/share_service.dart

import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/ranked/screens/result_screen.dart' show ShareableResultCard; 
import '../../features/ranked/utils/rank_utils.dart'; 
import '../providers/auth_provider.dart';

final shareServiceProvider = Provider<ShareService>((ref) => ShareService(ref));

class ShareService {
  final Ref _ref;
  ShareService(this._ref);

  Future<void> shareResult({
    required BuildContext context,
    required ScreenshotController screenshotController,
    // --- FIX IS HERE ---
    required String username,      // Added username parameter
    required String scenarioName,
    required String finalScore,    // Changed to String
    required String rankName,
    required Color rankColor,
    // --- END OF FIX ---
  }) async {
    try {
      final imageBytes = await screenshotController.captureFromWidget(
        InheritedTheme.captureAll(
          context,
          Material(
            color: Colors.transparent,
            child: ShareableResultCard(
              username: username,
              scenarioName: scenarioName,
              finalScore: finalScore, // Pass the String directly
              rankName: rankName,
              rankColor: rankColor,
            ),
          ),
        ),
        delay: Duration.zero,
      );

      final shareText = 'I just hit a new score of $finalScore in $scenarioName on RepDuel! Can you beat it? #RepDuel';

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
      debugPrint("[ShareService] Error during shareResult: $e");
      throw Exception('Failed to share result: $e');
    }
  }
}