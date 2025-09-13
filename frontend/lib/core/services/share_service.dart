// frontend/lib/core/services/share_service.dart

import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/ranked/screens/result_screen.dart'
    show ShareableResultCard;

final shareServiceProvider = Provider<ShareService>((ref) => ShareService());

class ShareService {
  ShareService();

  Future<void> shareResult({
    required BuildContext context,
    required ScreenshotController screenshotController,
    required String username,
    required String scenarioName,
    required String finalScore,
    required String rankName,
    required Color rankColor,
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
              finalScore: finalScore,
              rankName: rankName,
              rankColor: rankColor,
            ),
          ),
        ),
        delay: Duration.zero,
      );

      final shareText =
          'I just hit a new score of $finalScore in $scenarioName on RepDuel! Can you beat it? #RepDuel';

      final List<XFile> filesToShare;

      if (kIsWeb) {
        filesToShare = [
          XFile.fromData(
            imageBytes,
            name: 'repduel_result.png',
            mimeType: 'image/png',
          )
        ];
      } else {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/repduel_result.png';
        await File(path).writeAsBytes(imageBytes);
        filesToShare = [XFile(path)];
      }

      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          files: filesToShare,
        ),
      );
    } catch (e) {
      debugPrint("[ShareService] Error during shareResult: $e");
      throw Exception('Failed to share result: $e');
    }
  }
}
