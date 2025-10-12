import 'package:flutter_test/flutter_test.dart';

import 'package:repduel/core/services/secure_storage_service.dart';

void main() {
  group('SecureStorageService', () {
    test('stores and retrieves tokens using the injected store', () async {
      final memoryStore = InMemoryKeyValueStore();
      final service = SecureStorageService(secureStore: memoryStore);

      await service.writeToken('abc123');
      expect(await service.readToken(), 'abc123');

      await service.deleteToken();
      expect(await service.readToken(), isNull);
    });

    test('clearAll removes all entries', () async {
      final memoryStore = InMemoryKeyValueStore();
      final service = SecureStorageService(secureStore: memoryStore);

      await service.writeToken('token');
      await service.clearAll();

      expect(await service.readToken(), isNull);
    });
  });
}
