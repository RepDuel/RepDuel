import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/secure_storage_service.dart';

final workoutHistoryProvider =
    FutureProvider.family<List<RoutineSubmissionEntry>, String>(
        (ref, userId) async {
  final storage = SecureStorageService();
  final token = await storage.readToken();

  final res = await http.get(
    Uri.parse('http://localhost:8000/api/v1/routine_submission/user/$userId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (res.statusCode != 200) {
    throw Exception('Failed to load workout history');
  }

  final List<dynamic> jsonData = json.decode(res.body);
  return jsonData.map((e) => RoutineSubmissionEntry.fromJson(e)).toList();
});

class RoutineSubmissionEntry {
  final String id;
  final String routineId;
  final String status;
  final String completionTimestamp;

  RoutineSubmissionEntry({
    required this.id,
    required this.routineId,
    required this.status,
    required this.completionTimestamp,
  });

  factory RoutineSubmissionEntry.fromJson(Map<String, dynamic> json) {
    return RoutineSubmissionEntry(
      id: json['id'],
      routineId: json['routine_id'],
      status: json['status'],
      completionTimestamp: json['completion_timestamp'],
    );
  }
}
