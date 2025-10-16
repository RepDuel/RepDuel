// frontend/lib/core/services/key_value_store.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Defines the interface used to persist key/value pairs securely.
///
/// The abstraction allows tests to supply in-memory stores without
/// touching platform channels.
abstract class SecureKeyValueStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class SharedPreferencesKeyValueStore implements SecureKeyValueStore {
  SharedPreferencesKeyValueStore({
    SharedPreferences? preferences,
    this.keyPrefix = '',
  }) : _preferences = preferences;

  SharedPreferences? _preferences;
  final String keyPrefix;

  Future<SharedPreferences> _resolvePreferences() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    final prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    return prefs;
  }

  String _prefixed(String key) => '$keyPrefix$key';

  @override
  Future<void> write(String key, String value) async {
    final prefs = await _resolvePreferences();
    await prefs.setString(_prefixed(key), value);
  }

  @override
  Future<String?> read(String key) async {
    final prefs = await _resolvePreferences();
    return prefs.getString(_prefixed(key));
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _resolvePreferences();
    await prefs.remove(_prefixed(key));
  }

  @override
  Future<void> deleteAll() async {
    if (keyPrefix.isEmpty) {
      return;
    }
    final prefs = await _resolvePreferences();
    final keysToRemove = prefs
        .getKeys()
        .where((storedKey) => storedKey.startsWith(keyPrefix))
        .toList(growable: false);
    for (final storedKey in keysToRemove) {
      await prefs.remove(storedKey);
    }
  }
}

class InMemoryKeyValueStore implements SecureKeyValueStore {
  InMemoryKeyValueStore({this.keyPrefix = ''});

  final Map<String, String> _store = <String, String>{};
  final String keyPrefix;

  String _prefixed(String key) => '$keyPrefix$key';

  @override
  Future<void> write(String key, String value) async {
    _store[_prefixed(key)] = value;
  }

  @override
  Future<String?> read(String key) async => _store[_prefixed(key)];

  @override
  Future<void> delete(String key) async {
    _store.remove(_prefixed(key));
  }

  @override
  Future<void> deleteAll() async {
    if (keyPrefix.isEmpty) {
      return;
    }
    _store.removeWhere((storedKey, _) => storedKey.startsWith(keyPrefix));
  }
}
