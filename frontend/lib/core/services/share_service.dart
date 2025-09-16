// frontend/lib/core/services/share_service.dart

import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../config/env.dart';

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

  /// Build the canonical share URL for a routine
  Uri buildRoutineUrl({required String routineId}) {
    final base = Env.publicBaseUrl;
    return Uri.parse(base).resolve('/routines/play').replace(
      queryParameters: {'routineId': routineId},
    );
  }

  Future<void> shareRoutineLink({
    required String routineId,
    required String routineName,
  }) async {
    try {
      // Build a universal link that the app can open via GoRouter
      // Path: /routines/play?routineId=ID
      final url = buildRoutineUrl(routineId: routineId);

      final text = 'Check out my routine "$routineName" on RepDuel: $url';

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'RepDuel Routine',
        ),
      );
    } catch (e) {
      debugPrint("[ShareService] Error during shareRoutineLink: $e");
      throw Exception('Failed to share routine link: $e');
    }
  }

  /// Show a popup with the routine link and copy/share actions
  Future<void> showShareRoutineDialog({
    required BuildContext context,
    required String routineId,
    required String routineName,
  }) async {
    final url = buildRoutineUrl(routineId: routineId).toString();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Share routine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Link'),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await shareRoutineLink(
                    routineId: routineId,
                    routineName: routineName,
                  );
                } catch (_) {}
              },
              child: const Text('Share…'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
