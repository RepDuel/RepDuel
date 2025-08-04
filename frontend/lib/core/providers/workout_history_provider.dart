// frontend/lib/core/providers/workout_history_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/secure_storage_service.dart';
import '../models/routine_submission_read.dart';
import 'package:http/http.dart' as http;
import 'package:frontend/core/config/env.dart';

final workoutHistoryProvider =
    FutureProvider.family<List<RoutineSubmissionRead>, String>(
        (ref, userId) async {
  final storage = SecureStorageService();
  final token = await storage.readToken();

  final res = await http.get(
    Uri.parse('${Env.baseUrl}/api/v1/routine_submission/user/$userId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to load workout history');
  }

  final List<dynamic> jsonData = json.decode(res.body);
  return jsonData.map((e) => RoutineSubmissionRead.fromJson(e)).toList();
});
