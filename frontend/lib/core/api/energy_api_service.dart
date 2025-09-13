// frontend/lib/core/api/energy_api_service.dart

import '../utils/http_client.dart';

class EnergyApiService {
  final HttpClient _client;

  EnergyApiService(this._client);

  Future<int> getLatestEnergy(String userId) async {
    final response = await _client.get('/energy/latest/$userId');

    // Handle cases where data is a string or int
    final dynamic rawData = response.data;
    if (rawData is int) return rawData;
    if (rawData is String) return int.tryParse(rawData) ?? 0;

    return 0;
  }
}
