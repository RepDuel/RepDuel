// frontend/lib/core/services/secure_storage_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;

export 'key_value_store.dart'
    show
        SecureKeyValueStore,
        SharedPreferencesKeyValueStore,
        InMemoryKeyValueStore;
import 'key_value_store.dart';
import 'secure_storage_store_factory.dart'
    if (dart.library.html) 'secure_storage_store_factory_web.dart';

/// Persists authentication tokens using the most secure option per platform.
/// - Native (iOS/Android/macOS/Windows/Linux): uses a secure store created by
///   [createSecureKeyValueStore()] (e.g., Keychain/Keystore-backed).
/// - Web: falls back to [SharedPreferencesKeyValueStore] (localStorage),
///   namespaced to reduce key collisions.
///
/// NOTE:
/// Some platform stores (and mocks) have inconsistent `deleteAll` behavior if
/// options/namespaces differ. To be robust, `clearAll()` calls `deleteAll()`
/// and then explicitly deletes the known keys (like the auth token) as a
/// fallback so tests don’t flake and production remains deterministic.
class SecureStorageService {
  static const String _tokenKey = 'repduel.auth_token';

  SecureStorageService({
    SecureKeyValueStore? secureStore,
    SecureKeyValueStore? webFallbackStore,
  })  : _secureStore = secureStore ?? createSecureKeyValueStore(),
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

  /// Clears all keys stored by the active store namespace.
  /// Also explicitly deletes the known auth token to cover stores whose
  /// `deleteAll` might not wipe entries written with slightly different
  /// option sets.
  Future<void> clearAll() async {
    await _activeStore.deleteAll();
    await _activeStore.delete(_tokenKey);
  }
}
