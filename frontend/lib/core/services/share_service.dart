// frontend/lib/core/services/share_service.dart

import 'dart:io' show File; // Import File for path operations
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
import '../providers/auth_provider.dart'; // Import the auth provider

// A Riverpod provider that creates an instance of our ShareService.
// It injects the Ref so the service can access other providers.
final shareServiceProvider = Provider<ShareService>((ref) => ShareService(ref));

class ShareService {
  final Ref _ref; // Store the Ref

  ShareService(this._ref); // Constructor to receive Ref

  /// Captures a widget and shares it as an image, handling both web and native platforms.
  Future<void> shareResult({
    required BuildContext context, // Needed for InheritedTheme and SnackBar
    required ScreenshotController screenshotController,
    required Map<String, dynamic> scenarioData,
    required Map<String, dynamic> rankData,
    required int finalScore, // This is the score value that might need multiplier applied
  }) async {
    // Safely access user data from authProvider's AsyncValue.
    final authStateData = _ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    
    // Provide default values if user data is not available.
    final username = user?.username ?? 'An Athlete';
    final scenarioName = scenarioData['name'] ?? 'Scenario';
    final currentRank = rankData['current_rank'] ?? 'Unranked';
    final rankColor = getRankColor(currentRank); // Get color from RankUtils

    // Apply weight multiplier for display purposes, default to 1.0 if not available.
    final weightMultiplier = user?.weightMultiplier ?? 1.0;
    // Ensure the final score passed to ShareableResultCard is already scaled if needed.
    // The original code scaled it in shareResult, let's maintain that for consistency.
    final scaledFinalScore = (finalScore * weightMultiplier).round(); 

    try {
      // Capture the widget as an image.
      final imageBytes = await screenshotController.captureFromWidget(
        // InheritedTheme.captureAll ensures the widget uses the app's theme.
        InheritedTheme.captureAll(
          context, // Use the context passed to the method
          Material( // Wrap with Material for theme inheritance
            color: Colors.transparent, // Ensure the material is transparent
            child: ShareableResultCard(
              username: username,
              scenarioName: scenarioName,
              finalScore: scaledFinalScore, // Use the scaled score
              rankName: currentRank,
              rankColor: rankColor,
            ),
          ),
        ),
        delay: Duration.zero, // Capture immediately
      );

      // Define the text to share alongside the image.
      final shareText = 'I just hit a new score of $scaledFinalScore in $scenarioName on RepDuel! Can you beat it? #RepDuel';

      // Platform-aware sharing logic using share_plus.
      if (kIsWeb) {
        // On web, use shareXFiles with data directly.
        await Share.shareXFiles(
          [XFile.fromData(imageBytes, name: 'repduel_result.png', mimeType: 'image/png')],
          text: shareText,
        );
      } else {
        // On native platforms, save to a temporary file first.
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/repduel_result.png';
        await File(path).writeAsBytes(imageBytes);
        await Share.shareXFiles([XFile(path)], text: shareText);
      }
    } catch (e) {
      debugPrint("[ShareService] Error during shareResult: $e");
      // Let the caller decide how to display the error (e.g., via SnackBar).
      // Re-throwing allows the caller's try-catch to handle it.
      throw Exception('Failed to share result: $e');
    }
  }
}