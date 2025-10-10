import '../config/env.dart';

String _trimTrailingSlashes(String value) {
  var result = value.trim();
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

String _normalizePath(String path) {
  if (path.isEmpty) {
    return '';
  }
  return path.startsWith('/') ? path : '/$path';
}

String apiBaseUrl() {
  final base = _trimTrailingSlashes(Env.backendUrl);
  return base.isEmpty ? '' : '$base/api/v1';
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
  if (queryParameters == null || queryParameters.isEmpty) {
    return uri;
  }

  final qp = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null) {
      continue;
    }
    qp[entry.key] = value.toString();
  }

  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      ...qp,
    },
  );
}
