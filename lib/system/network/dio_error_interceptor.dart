import 'dart:convert';

import 'package:dio/dio.dart';

/// Enriches [DioException] messages with request context (method, URL, status
/// code, response body) so logs and error dialogs identify the failing
/// request — e.g. which instance a proxied request actually hit.
///
/// The message and readable representation are redacted. The exception type,
/// cause, request options, and response are preserved, so existing handling and
/// `error.response?.statusCode` checks are unaffected. Headers are never
/// included; credentials are redacted from the URL — the `apikey` query
/// parameter, `user:password` userinfo, and path segments carrying them (the
/// NZBGet JSON-RPC clients embed credentials as a path segment).
class LunaDioErrorInterceptor extends Interceptor {
  const LunaDioErrorInterceptor({this.maxResponseBodyLength = 500});

  final int maxResponseBodyLength;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final enriched = err.copyWith(
      message: _redact(_describe(err), err.requestOptions),
    );
    // Dio also prints the original cause, which can contain the request URL.
    enriched.stringBuilder = (error) => _redact(
      defaultDioExceptionReadableStringBuilder(error),
      error.requestOptions,
    );
    handler.next(enriched);
  }

  String _describe(DioException err) {
    final buffer = StringBuffer(
      '${err.requestOptions.method} ${_redactedUri(err.requestOptions)}',
    );
    final response = err.response;
    if (response != null) {
      buffer.write('\nStatus: ${response.statusCode}');
      final reason = response.statusMessage;
      if (reason != null && reason.isNotEmpty) buffer.write(' ($reason)');
      final body = _responseBody(err);
      if (body != null) buffer.write('\nResponse: $body');
    } else if (err.message != null) {
      buffer.write('\n${err.message}');
    }
    return buffer.toString();
  }

  Uri _redactedUri(RequestOptions options) {
    final uri = options.uri;
    var path = uri.path;
    if (path.contains(':')) {
      final segments = uri.pathSegments
          .map((s) => s.contains(':') ? '***' : s)
          .toList();
      path = uri.path.startsWith('/')
          ? '/${segments.join('/')}'
          : segments.join('/');
    }
    final query = {
      for (final entry in uri.queryParametersAll.entries)
        entry.key: _isApiKey(entry.key) ? ['***'] : entry.value,
    };
    return uri.replace(
      path: path,
      userInfo: uri.userInfo.isEmpty ? null : '***',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  String? _responseBody(DioException err) {
    final data = err.response?.data;
    if (data == null) return null;
    String text;
    if (data is String) {
      text = data;
    } else {
      try {
        text = jsonEncode(data);
      } catch (_) {
        text = data.toString();
      }
    }
    text = text.trim();
    if (text.isEmpty) return null;
    text = _redact(text, err.requestOptions);
    if (text.length > maxResponseBodyLength) {
      text = '${text.substring(0, maxResponseBodyLength)}…';
    }
    return text;
  }

  static bool _isApiKey(String key) =>
      key.toLowerCase().replaceAll(RegExp('[-_]'), '') == 'apikey' ||
      key.toLowerCase() == 'x-api-key';

  String _redact(String text, RequestOptions options) {
    final secrets = <String>{};
    for (final entry in options.uri.queryParametersAll.entries) {
      if (_isApiKey(entry.key)) secrets.addAll(entry.value);
    }
    for (final entry in options.headers.entries) {
      if (_isApiKey(entry.key)) secrets.add(entry.value.toString());
      if (entry.key.toLowerCase() == 'authorization') {
        final value = entry.value.toString();
        secrets.add(value);
        secrets.add(value.split(' ').last);
      }
    }
    final uri = options.uri;
    for (final credentials in [
      uri.userInfo,
      ...uri.pathSegments.where((s) => s.contains(':')),
    ]) {
      secrets.add(credentials);
      secrets.addAll(credentials.split(':'));
    }
    final values = secrets.where((value) => value.isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final secret in values) {
      text = text.replaceAll(secret, '***');
      text = text.replaceAll(Uri.encodeComponent(secret), '***');
    }
    return text;
  }
}
