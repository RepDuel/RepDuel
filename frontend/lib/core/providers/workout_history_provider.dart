// frontend/lib/core/providers/workout_history_provider.dart

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/routine_submission_read.dart';
import '../providers/auth_provider.dart';

final workoutHistoryProvider =
    FutureProvider.family<List<RoutineSubmissionRead>, String>(
  (ref, userId) async {
    final token = ref.read(authProvider).valueOrNull?.token;

    if (token == null) {
      debugPrint(
        "[workoutHistoryProvider] Token is null. User not authenticated or auth state not loaded.",
      );
      throw Exception("Authentication token not available. Please log in.");
    }

    final url =
        Uri.parse('${Env.baseUrl}/api/v1/routine_submission/user/$userId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((e) => RoutineSubmissionRead.fromJson(e)).toList();
      } else if (response.statusCode == 401) {
        throw Exception("Unauthorized (401). Please log in again.");
      } else {
        throw Exception(
          'Failed to load workout history: HTTP ${response.statusCode} - ${response.reasonPhrase ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint("[workoutHistoryProvider] Error fetching workout history: $e");
      throw Exception('Failed to load workout history: $e');
    }
  },
);
