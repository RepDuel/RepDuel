# flutter_secure_storage_web (minimal stub)

This package intentionally disables the upstream web implementation of
`flutter_secure_storage`.

The application relies on a custom `SecureKeyValueStore` fallback for web
platforms, so this stub only provides a no-op registrar to satisfy the
federated plugin loader without pulling in additional dependencies.
