// frontend/lib/core/services/secure_storage_store_factory.dart

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

import 'key_value_store.dart';

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

SecureKeyValueStore createSecureKeyValueStore() {
  if (kIsWeb) {
    return SharedPreferencesKeyValueStore(
      keyPrefix: 'flutter_secure_storage_web:',
    );
  }
  return FlutterSecureKeyValueStore();
}
