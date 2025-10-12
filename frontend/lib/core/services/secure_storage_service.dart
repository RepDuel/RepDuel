// frontend/lib/core/services/secure_storage_service.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show
        AndroidOptions,
        FlutterSecureStorage,
        IOSOptions,
        KeychainAccessibility,
        LinuxOptions,
        MacOsOptions,
        WindowsOptions;
import 'package:shared_preferences/shared_preferences.dart';

/// Defines the interface used by [SecureStorageService] to persist key/value
/// pairs. The abstraction allows tests to supply in-memory stores without
/// touching platform channels.
abstract class SecureKeyValueStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) {
    return _storage.write(
      key: key,
      value: value,
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      mOptions: const MacOsOptions(),
      lOptions: const LinuxOptions(),
      wOptions: const WindowsOptions(),
    );
  }

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

class SharedPreferencesKeyValueStore implements SecureKeyValueStore {
  SharedPreferencesKeyValueStore({SharedPreferences? preferences})
      : _preferences = preferences;

  SharedPreferences? _preferences;

  Future<SharedPreferences> _resolvePreferences() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    return prefs;
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _resolvePreferences();
    await prefs.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await _resolvePreferences();
    return prefs.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _resolvePreferences();
    await prefs.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    final prefs = await _resolvePreferences();
    await prefs.clear();
  }
}

class InMemoryKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}

class SecureStorageService {
  static const String _tokenKey = 'flutter.auth_token';

  SecureStorageService({
    SecureKeyValueStore? secureStore,
    SecureKeyValueStore? webFallbackStore,
  })  : _secureStore = secureStore ?? FlutterSecureKeyValueStore(),
        _webStore = webFallbackStore ?? SharedPreferencesKeyValueStore();

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
