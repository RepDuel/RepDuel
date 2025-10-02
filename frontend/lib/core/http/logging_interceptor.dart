import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

const _requestStartKey = '__request_start__';

/// A lightweight Dio interceptor that only logs errors and requests that
/// exceed a configurable latency threshold.
class CompactLoggingInterceptor extends Interceptor {
  const CompactLoggingInterceptor({
    this.slowRequestThreshold = const Duration(milliseconds: 800),
  });

  /// Any request that takes longer than this duration will be logged.
  final Duration slowRequestThreshold;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestStartKey] = DateTime.now().microsecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final duration = _consumeDuration(response.requestOptions.extra);
    if (duration != null && duration >= slowRequestThreshold) {
      debugPrint(
        '[HTTP][slow] ${response.statusCode} '
        '${response.requestOptions.method} ${response.requestOptions.uri} '
        '(${duration.inMilliseconds}ms)',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final duration = _consumeDuration(err.requestOptions.extra);
    final status = err.response?.statusCode;
    final statusText = status != null ? status.toString() : 'ERR';
    debugPrint(
      '[HTTP][error] $statusText ${err.requestOptions.method} '
      '${err.requestOptions.uri}${_formatDuration(duration)} — ${err.message}',
    );
    handler.next(err);
  }

  Duration? _consumeDuration(Map<String, dynamic> extra) {
    final startMicros = extra.remove(_requestStartKey);
    if (startMicros is int) {
      return Duration(
        microseconds: DateTime.now().microsecondsSinceEpoch - startMicros,
      );
    }
    return null;
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '';
    }
    return ' (${duration.inMilliseconds}ms)';
  }
}
