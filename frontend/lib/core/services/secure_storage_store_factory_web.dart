// frontend/lib/core/services/secure_storage_store_factory_web.dart

import 'key_value_store.dart';

SecureKeyValueStore createSecureKeyValueStore() =>
    SharedPreferencesKeyValueStore();
