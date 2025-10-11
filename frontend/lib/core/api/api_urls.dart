import '../config/env.dart';

String _trimTrailingSlashes(String value) {
  var result = value.trim();
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

String _normalizePath(String path) {
  if (path.isEmpty) return '';
  return path.startsWith('/') ? path : '/$path';
}

bool _hasVersionedApiPath(String value) {
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  if (uri == null) return false;
  final normalizedPath = _trimTrailingSlashes(uri.path);
  // e.g., /api/v1, /api/v2, ...
  return RegExp(r'^/api/v\d+$').hasMatch(normalizedPath);
}

String apiBaseUrl() {
  final base = _trimTrailingSlashes(Env.backendUrl);
  if (base.isEmpty) return '';
  if (_hasVersionedApiPath(base)) return base;
  return '$base/api/v1';
}

String apiUrl(String path) {
  final base = apiBaseUrl();
  return '$base${_normalizePath(path)}';
}

Uri apiUri(
  String path, {
  Map<String, dynamic>? queryParameters,
}) {
  final uri = Uri.parse(apiUrl(path));
  if (queryParameters == null || queryParameters.isEmpty) return uri;

  final qp = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null) continue;
    qp[entry.key] = value.toString();
  }
  return uri.replace(queryParameters: qp);
}
