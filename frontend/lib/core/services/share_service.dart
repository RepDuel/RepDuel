// frontend/lib/core/services/share_service.dart

import 'dart:io' show File;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/ranked/screens/result_screen.dart'
    show ShareableResultCard;
import '../providers/api_providers.dart';

class RoutineShareDetails {
  RoutineShareDetails({required this.code, required this.name});

  final String code;
  final String name;

  factory RoutineShareDetails.fromJson(Map<String, dynamic> json) {
    final rawCode = (json['code'] as String?) ?? '';
    if (rawCode.trim().isEmpty) {
      throw Exception('Share code missing from response.');
    }
    return RoutineShareDetails(
      code: rawCode.trim().toUpperCase(),
      name: (json['name'] as String?) ?? 'Shared Routine',
    );
  }
}

final shareServiceProvider = Provider<ShareService>((ref) => ShareService(ref));

class ShareService {
  ShareService(this._ref);

  final Ref _ref;

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

  Future<RoutineShareDetails> _createRoutineShare({required String routineId}) async {
    final client = _ref.read(privateHttpClientProvider);
    try {
      final response = await client.post('/routines/$routineId/share');
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to create share code (status ${response.statusCode}).');
      }
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected response when creating share code.');
      }
      return RoutineShareDetails.fromJson(data);
    } on DioException catch (err) {
      final message = err.response?.data is Map<String, dynamic>
          ? (err.response?.data['detail'] as String?)
          : err.message;
      throw Exception(message ?? 'Failed to create share code.');
    }
  }

  Future<void> shareRoutineCode({
    required String routineName,
    required String shareCode,
  }) async {
    try {
      final text =
          'Check out my routine "$routineName" on RepDuel! Use share code $shareCode in the app to import it.';

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'RepDuel Routine',
        ),
      );
    } catch (e) {
      debugPrint("[ShareService] Error during shareRoutineCode: $e");
      throw Exception('Failed to share routine code: $e');
    }
  }

  /// Show a popup with the share code and copy/share actions
  Future<void> showShareRoutineDialog({
    required BuildContext context,
    required String routineId,
    required String routineName,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    late final RoutineShareDetails share;
    try {
      share = await _createRoutineShare(routineId: routineId);
    } catch (e) {
      debugPrint("[ShareService] Error creating share code: $e");
      if (navigator.mounted) {
        navigator.pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return;
    }

    if (navigator.mounted) {
      navigator.pop();
    }

    if (!context.mounted) {
      return;
    }

    final code = share.code;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Share routine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share code'),
              const SizedBox(height: 12),
              Center(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Anyone can import this routine by entering the code on the routines screen.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share code copied to clipboard')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await shareRoutineCode(
                    routineName: routineName,
                    shareCode: code,
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
