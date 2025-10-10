// frontend/lib/features/ranked/providers/score_history_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_urls.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/score_history_entry.dart';

final scoreHistoryProvider =
    FutureProvider.autoDispose.family<List<ScoreHistoryEntry>, String>(
  (ref, scenarioId) async {
    // Safely access user and token from authProvider
    final authStateData = ref.read(authProvider).valueOrNull;
    final user = authStateData?.user;
    final token = authStateData?.token;

    // If user or token is null, the user is not authenticated.
    // Throw an exception to indicate this, which will be caught by AsyncValue.
    if (user == null || token == null) {
      debugPrint(
          "[ScoreHistoryProvider] User or token is null. User not authenticated.");
      throw Exception("User not authenticated. Please log in.");
    }

    // Construct the URL using user ID.
    final url = apiUrl('/scores/user/${user.id}/scenario/$scenarioId');

    debugPrint(
        'Fetching score history for user: ${user.id}, scenario: $scenarioId');
    debugPrint('Score History URL: $url');
    debugPrint(
        'Token available: ${token.isNotEmpty}'); // Check token availability

    try {
      final response = await http.get(
        apiUri('/scores/user/${user.id}/scenario/$scenarioId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Use the safely retrieved token
        },
      ).timeout(const Duration(seconds: 10)); // Add timeout for robustness

      debugPrint('Score History Response Status: ${response.statusCode}');
      debugPrint('Score History Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final entries =
            data.map((item) => ScoreHistoryEntry.fromJson(item)).toList();
        // Sort entries by date
        entries.sort((a, b) => a.date.compareTo(b.date));
        return entries;
      } else if (response.statusCode == 403) {
        // Specific error for subscription requirements
        throw Exception("Upgrade to Gold to see your history. Status: 403");
      } else {
        // Generic error for other non-200 status codes
        throw Exception(
            "Failed to load score history. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      // Catch any exceptions (network errors, JSON decoding errors, etc.)
      debugPrint("[ScoreHistoryProvider] Error fetching score history: $e");
      // Rethrow the exception so AsyncValue can handle it.
      throw Exception('Failed to load score history: $e');
    }
  },
);
