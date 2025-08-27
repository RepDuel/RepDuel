// frontend/lib/core/providers/workout_history_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint; // For logging

import '../config/env.dart';
import '../models/routine_submission_read.dart';
import '../providers/auth_provider.dart'; // Import auth provider

// Provider for workout history, dependent on userId.
// It will fetch data using the token retrieved from authProvider.
final workoutHistoryProvider =
    FutureProvider.family<List<RoutineSubmissionRead>, String>(
        (ref, userId) async {

  // Safely get the token from authProvider using the authTokenProvider
  // or by directly accessing AsyncValue.valueOrNull.
  // Using authTokenProvider is cleaner if it's available and does the safe unwrapping.
  // If authTokenProvider is not globally accessible, directly access authProvider.
  
  // Option 1: Using the dedicated authTokenProvider (preferred if available)
  // final token = ref.read(authTokenProvider); 

  // Option 2: Directly accessing authProvider.valueOrNull
  final token = ref.read(authProvider).valueOrNull?.token;

  // If token is null, it means the user is not authenticated or auth state is loading/errored.
  // The AuthInterceptor on the private client would block this request anyway.
  // We can throw an exception here to make the provider enter an error state immediately.
  if (token == null) {
    debugPrint("[workoutHistoryProvider] Token is null. User not authenticated or auth state not loaded.");
    throw Exception("Authentication token not available. Please log in.");
  }

  final url = Uri.parse('${Env.baseUrl}/api/v1/routine_submission/user/$userId');
  
  try {
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Use the safely retrieved token
      },
    ).timeout(const Duration(seconds: 10)); // Added timeout for robustness

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((e) => RoutineSubmissionRead.fromJson(e)).toList();
    } else if (response.statusCode == 401) {
      // Handle unauthorized specifically
      throw Exception("Unauthorized (401). Please log in again.");
    } else {
      // Handle other non-200 status codes
      throw Exception('Failed to load workout history: HTTP ${response.statusCode} - ${response.reasonPhrase ?? 'Unknown error'}');
    }
  } catch (e) {
    // Catch any exceptions during the HTTP request or JSON decoding.
    debugPrint("[workoutHistoryProvider] Error fetching workout history: $e");
    // Rethrow to be caught by AsyncValue.when in the UI.
    throw Exception('Failed to load workout history: $e');
  }
});