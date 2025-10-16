import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Wasm-safe web implementation of [FlutterSecureStoragePlatform]
/// that persists values via [SharedPreferences].
class FlutterSecureStorageWeb extends FlutterSecureStoragePlatform {
  FlutterSecureStorageWeb();

  static void registerWith([Object? registrar]) {
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWeb();
  }

  static const String _storagePrefix = 'flutter_secure_storage_web:';

  SharedPreferences? _cachedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _cachedPrefs ??= await SharedPreferences.getInstance();

  String _prefixed(String key) => '$_storagePrefix$key';

  @override
  Future<void> write({
    required String key,
    required String? value,
    Map<String, String>? options,
  }) async {
    final prefs = await _prefs;
    final prefKey = _prefixed(key);

    if (value == null) {
      await prefs.remove(prefKey);
    } else {
      await prefs.setString(prefKey, value);
    }
  }

  @override
  Future<String?> read({
    required String key,
    Map<String, String>? options,
  }) async {
    final prefs = await _prefs;
    return prefs.getString(_prefixed(key));
  }

  @override
  Future<bool> containsKey({
    required String key,
    Map<String, String>? options,
  }) async {
    final prefs = await _prefs;
    return prefs.containsKey(_prefixed(key));
  }

  @override
  Future<Map<String, String>> readAll({
    Map<String, String>? options,
  }) async {
    final prefs = await _prefs;
    final Map<String, String> values = {};

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_storagePrefix)) {
        final value = prefs.getString(key);
        if (value != null) {
          values[key.substring(_storagePrefix.length)] = value;
        }
      }
    }

    return values;
  }

  @override
  Future<void> delete({
    required String key,
    Map<String, String>? options,
  }) async {
    final prefs = await _prefs;
    await prefs.remove(_prefixed(key));
  }

  @override
  Future<void> deleteAll({
    Map<String, String>? options,
  }) async {
    final prefs = await _prefs;
    final keysToRemove = prefs
        .getKeys()
        .where((key) => key.startsWith(_storagePrefix))
        .toList(growable: false);

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
