import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:repduel/core/api/api_client.dart';
import 'package:repduel/core/services/secure_storage_service.dart';

class QueueClient extends http.BaseClient {
  QueueClient(this._queue);

  final List<Object> _queue;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount += 1;
    if (_queue.isEmpty) {
      throw StateError('No response queued');
    }
    final next = _queue.removeAt(0);
    if (next is http.Response) {
      return http.StreamedResponse(
        Stream<List<int>>.value(next.bodyBytes),
        next.statusCode,
        headers: next.headers,
        reasonPhrase: next.reasonPhrase,
      );
    }
    if (next is Exception) {
      throw next;
    }
    throw ArgumentError('Unsupported queue entry: $next');
  }
}

void main() {
  group('ApiClient', () {
    test('retries once on 5xx responses before succeeding', () async {
      final client = QueueClient([
        http.Response('Server error', 500),
        http.Response(jsonEncode({'ok': true}), 200,
            headers: {'content-type': 'application/json'}),
      ]);
      final storage = SecureStorageService(secureStore: InMemoryKeyValueStore());
      final apiClient = ApiClient(
        baseUrl: 'https://example.com',
        secureStorage: storage,
        httpClient: client,
        retryBackoff: const Duration(milliseconds: 10),
      );

      final response = await apiClient.get('/retry');

      expect(response.statusCode, 200);
      expect(client.requestCount, 2);
    });

    test('invokes refresh callback when encountering a 401', () async {
      final client = QueueClient([
        http.Response('Unauthorized', 401,
            headers: {'content-type': 'application/json'}),
        http.Response(jsonEncode({'ok': true}), 200,
            headers: {'content-type': 'application/json'}),
      ]);
      final store = SecureStorageService(secureStore: InMemoryKeyValueStore());
      var refreshCalls = 0;
      final apiClient = ApiClient(
        baseUrl: 'https://example.com',
        secureStorage: store,
        httpClient: client,
        retryBackoff: const Duration(milliseconds: 10),
        onUnauthorized: () async {
          refreshCalls += 1;
          return 'refreshed-token';
        },
      );

      final response = await apiClient.get('/needs-auth');

      expect(response.statusCode, 200);
      expect(refreshCalls, 1);
      expect(await store.readToken(), 'refreshed-token');
    });

    test('throws ApiException with friendly message on 404', () async {
      final client = QueueClient([
        http.Response(jsonEncode({'detail': 'Not found'}), 404,
            headers: {'content-type': 'application/json'}),
      ]);
      final storage = SecureStorageService(secureStore: InMemoryKeyValueStore());
      final apiClient = ApiClient(
        baseUrl: 'https://example.com',
        secureStorage: storage,
        httpClient: client,
        retryBackoff: const Duration(milliseconds: 10),
      );

      expect(
        () => apiClient.get('/missing'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Not found')),
      );
    });
  });
}
