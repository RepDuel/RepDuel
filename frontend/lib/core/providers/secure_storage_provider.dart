// frontend/lib/core/providers/secure_storage_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
