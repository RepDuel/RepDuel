# flutter_secure_storage_web (stub)

This package provides a Wasm-compatible web implementation of
`flutter_secure_storage` for RepDuel. It replaces the federated
`flutter_secure_storage_web` package and stores values with
`SharedPreferences` without relying on `dart:js`, `dart:html`, or
`dart:js_util`.

## Usage

The app overrides the dependency in `frontend/pubspec.yaml`:

```yaml
dependency_overrides:
  flutter_secure_storage_web:
    path: packages/flutter_secure_storage_web_stub
```

## Future Work

Remove this package once the upstream web implementation becomes
Wasm-safe.
