// frontend/lib/features/ranked/providers/score_history_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/providers/auth_provider.dart';
import '../models/score_history_entry.dart';

final scoreHistoryProvider = FutureProvider.autoDispose.family<List<ScoreHistoryEntry>, String>((ref, scenarioId) async {
  final user = ref.watch(authProvider).user;
  if (user == null) throw Exception("User not authenticated");
  
  final url = '${Env.baseUrl}/api/v1/scores/user/${user.id}/scenario/$scenarioId';
  final token = ref.read(authProvider).token;

  // Debug: Print score history request
  print('Fetching score history for user: ${user.id}, scenario: $scenarioId');
  print('Score History URL: $url');
  print('Token available: ${token != null}');

  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );

  // Debug: Print score history response
  print('Score History Response Status: ${response.statusCode}');
  print('Score History Response Body: ${response.body}');

  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    final entries = data.map((item) => ScoreHistoryEntry.fromJson(item)).toList();
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  } else if (response.statusCode == 403) {
    throw Exception("Upgrade to Gold to see your history. Status: 403");
  } else {
    throw Exception("Failed to load score history. Status: ${response.statusCode}, Body: ${response.body}");
  }
});