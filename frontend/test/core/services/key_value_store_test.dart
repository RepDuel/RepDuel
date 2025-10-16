import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repduel/core/services/key_value_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesKeyValueStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('applies prefix when persisting values', () async {
      const prefix = 'repduel.secure.';
      final store = SharedPreferencesKeyValueStore(keyPrefix: prefix);

      await store.write('token', 'abc123');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('${prefix}token'), 'abc123');
    });

    test('deleteAll only removes keys with matching prefix', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'repduel.secure.token': 'secret',
        'theme_mode': 'dark',
      });
      final store = SharedPreferencesKeyValueStore(keyPrefix: 'repduel.secure.');

      await store.deleteAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getString('repduel.secure.token'), isNull);
    });
  });
}
