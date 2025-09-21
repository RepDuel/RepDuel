// frontend/lib/core/api/level_api_service.dart

import '../models/level_progress.dart';
import '../utils/http_client.dart';

class LevelApiService {
  final HttpClient _client;

  LevelApiService(this._client);

  Future<LevelProgress> getMyLevelProgress() async {
    final response = await _client.get('/levels/me');
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return LevelProgress.fromJson(data);
    }

    throw Exception('Unexpected response when loading level progress.');
  }
}
