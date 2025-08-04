class Env {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: '${Env.baseUrl}',
  );
}
