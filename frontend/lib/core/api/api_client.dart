// frontend/lib/core/api/api_client.dart

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/secure_storage_service.dart';

typedef TokenRefreshCallback = Future<String?> Function();

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message, cause: $cause)';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required SecureStorageService secureStorage,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
    this.maxRetries = 2,
    this.retryBackoff = const Duration(milliseconds: 600),
    TokenRefreshCallback? onUnauthorized,
  })  : _secureStorage = secureStorage,
        _httpClient = httpClient ?? http.Client(),
        _refreshToken = onUnauthorized;

  final String baseUrl;
  final SecureStorageService _secureStorage;
  final http.Client _httpClient;
  final Duration requestTimeout;
  final int maxRetries;
  final Duration retryBackoff;
  final TokenRefreshCallback? _refreshToken;

  Future<http.Response> get(String endpoint, {bool auth = true}) {
    return _send('GET', endpoint, auth: auth);
  }

  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) {
    return _send('POST', endpoint, body: body, auth: auth);
  }

  Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) {
    return _send('PUT', endpoint, body: body, auth: auth);
  }

  Future<http.Response> delete(String endpoint, {bool auth = true}) {
    return _send('DELETE', endpoint, auth: auth);
  }

  void close() {
    _httpClient.close();
  }

  Future<http.Response> _send(
    String method,
    String endpoint, {
    bool auth = true,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final encodedBody = body != null ? jsonEncode(body) : null;

    int attempt = 0;
    while (true) {
      try {
        final headers = await _buildHeaders(auth: auth);
        var response = await _dispatch(
          method,
          uri,
          headers: headers,
          body: encodedBody,
        ).timeout(requestTimeout);

        if (response.statusCode == 401 && auth && _refreshToken != null) {
          final refreshedToken = await _refreshToken();
          if (refreshedToken != null && refreshedToken.isNotEmpty) {
            await _secureStorage.writeToken(refreshedToken);
            final retryHeaders = await _buildHeaders(
              auth: auth,
              overrideToken: refreshedToken,
            );
            response = await _dispatch(
              method,
              uri,
              headers: retryHeaders,
              body: encodedBody,
            ).timeout(requestTimeout);
          } else {
            throw ApiException('Authentication required.', statusCode: 401);
          }
        }

        if (_shouldRetry(response.statusCode) && attempt < maxRetries) {
          attempt += 1;
          await Future.delayed(_backoffForAttempt(attempt));
          continue;
        }

        if (response.statusCode >= 400) {
          throw ApiException(
            _describeError(response),
            statusCode: response.statusCode,
          );
        }

        return response;
      } on TimeoutException catch (error) {
        if (attempt >= maxRetries) {
          throw ApiException(
            'Request to server timed out. Please try again.',
            cause: error,
          );
        }
      } on http.ClientException catch (error) {
        if (attempt >= maxRetries) {
          throw ApiException('Network error: ${error.message}', cause: error);
        }
      } on ApiException {
        rethrow;
      } catch (error) {
        throw ApiException('Unexpected error: $error', cause: error);
      }

      attempt += 1;
      await Future.delayed(_backoffForAttempt(attempt));
    }
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(uri, headers: headers, body: body);
      case 'PUT':
        return _httpClient.put(uri, headers: headers, body: body);
      case 'DELETE':
        return _httpClient.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  bool _shouldRetry(int statusCode) {
    return statusCode >= 500 && statusCode < 600;
  }

  Duration _backoffForAttempt(int attempt) {
    final multiplier = attempt <= 0 ? 1 : (1 << (attempt - 1));
    final millis = retryBackoff.inMilliseconds * multiplier;
    return Duration(milliseconds: millis.clamp(200, 5000));
  }

  Future<Map<String, String>> _buildHeaders({
    required bool auth,
    String? overrideToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (auth) {
      final token = overrideToken ?? await _secureStorage.readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  String _describeError(http.Response response) {
    final status = response.statusCode;
    try {
      final dynamic payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        final message = payload['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore decoding failures.
    }
    if (status == 401) {
      return 'Authentication required.';
    }
    if (status == 403) {
      return 'You do not have permission to perform this action.';
    }
    if (status == 404) {
      return 'The requested resource was not found.';
    }
    if (status == 429) {
      return 'Too many requests. Please slow down.';
    }
    return 'Request failed with status $status.';
  }
}
