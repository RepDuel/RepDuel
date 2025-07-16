import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/energy_api_service.dart';
import 'api_providers.dart';

final energyApiProvider = Provider<EnergyApiService>((ref) {
  final client = ref.read(privateHttpClientProvider);
  return EnergyApiService(client);
});
