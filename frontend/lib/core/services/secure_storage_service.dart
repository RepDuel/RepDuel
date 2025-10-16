// frontend/lib/core/services/secure_storage_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;

export 'key_value_store.dart'
    show SecureKeyValueStore, SharedPreferencesKeyValueStore,
        InMemoryKeyValueStore;
import 'key_value_store.dart';
import 'secure_storage_store_factory.dart'
    if (dart.library.html) 'secure_storage_store_factory_web.dart';

/// Persists authentication tokens using the most secure option for each
/// platform.
///
/// On the web we fall back to [SharedPreferencesKeyValueStore], which stores
/// data in `localStorage`. Because that storage is accessible to JavaScript, we
/// keep tokens namespaced and expect callers to mitigate XSS and rely on
/// short-lived tokens when targeting the web.
class SecureStorageService {
  static const String _tokenKey = 'repduel.auth_token';

  SecureStorageService({
    SecureKeyValueStore? secureStore,
    SecureKeyValueStore? webFallbackStore,
  })  : _secureStore =
            secureStore ?? createSecureKeyValueStore(),
        _webStore = webFallbackStore ??
            SharedPreferencesKeyValueStore(keyPrefix: 'repduel.secure.');

  final SecureKeyValueStore _secureStore;
  final SecureKeyValueStore _webStore;

  SecureKeyValueStore get _activeStore => kIsWeb ? _webStore : _secureStore;

  Future<void> writeToken(String token) {
    return _activeStore.write(_tokenKey, token);
  }

  Future<String?> readToken() {
    return _activeStore.read(_tokenKey);
  }

  Future<void> deleteToken() {
    return _activeStore.delete(_tokenKey);
  }

  Future<void> clearAll() {
    return _activeStore.deleteAll();
  }
}
