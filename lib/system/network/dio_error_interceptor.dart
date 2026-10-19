import 'dart:convert';

import 'package:dio/dio.dart';

/// Enriches [DioException] messages with request context (method, URL, status
/// code, response body) so logs and error dialogs identify the failing
/// request — e.g. which instance a proxied request actually hit.
///
/// The message and readable representation are redacted. The exception type,
/// cause, request options, and response are preserved, so existing handling and
/// `error.response?.statusCode` checks are unaffected. Headers are never
/// included; API keys, passwords, `user:password` userinfo, and credential
/// path segments are redacted from readable URLs. SABnzbd's positional rename
/// password and API keys inside submitted NZB URLs are also redacted.
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
        entry.key: _isSensitiveQueryParameter(uri, entry.key)
            ? ['***']
            : entry.value,
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

  static bool _isSensitiveQueryParameter(Uri uri, String key) =>
      _isApiKey(key) ||
      key.toLowerCase() == 'password' ||
      (key.toLowerCase() == 'value3' &&
          uri.queryParameters['mode'] == 'queue' &&
          uri.queryParameters['name'] == 'rename');

  Iterable<String> _querySecrets(Uri uri) sync* {
    for (final entry in uri.queryParametersAll.entries) {
      if (_isSensitiveQueryParameter(uri, entry.key)) yield* entry.value;
    }
    if (uri.queryParameters['mode'] == 'addurl') {
      for (final value in uri.queryParametersAll['name'] ?? const <String>[]) {
        final nested = Uri.tryParse(value);
        if (nested == null) continue;
        yield* _uriCredentials(nested);
        for (final entry in nested.queryParametersAll.entries) {
          if (_isSensitiveQueryParameter(nested, entry.key)) yield* entry.value;
        }
      }
    }
  }

  static final _credentialSeparator = RegExp(r':|%3[aA]');

  Iterable<String> _uriCredentials(Uri uri) sync* {
    if (uri.userInfo.isNotEmpty) {
      yield uri.userInfo;
      yield* uri.userInfo.split(_credentialSeparator);
      final credentials = Uri.decodeComponent(uri.userInfo);
      yield credentials;
      yield* credentials.split(':');
    }
    // Decoding and re-encoding cannot reproduce mixed serialized spellings.
    for (final serialized in uri.path.split('/')) {
      final segment = Uri.decodeComponent(serialized);
      if (segment.contains(':')) {
        yield serialized;
        yield* serialized.split(_credentialSeparator);
        yield segment;
        yield* segment.split(':');
      }
    }
  }

  String _redact(String text, RequestOptions options) {
    final secrets = _querySecrets(options.uri).toSet();
    for (final entry in options.headers.entries) {
      if (_isApiKey(entry.key)) secrets.add(entry.value.toString());
      if (entry.key.toLowerCase() == 'authorization') {
        final value = entry.value.toString();
        secrets.add(value);
        secrets.add(value.split(' ').last);
      }
    }
    secrets.addAll(_uriCredentials(options.uri));
    final values = <String>{};
    for (final secret in secrets.where((value) => value.isNotEmpty)) {
      final json = jsonEncode(secret);
      values.addAll([
        secret,
        json.substring(1, json.length - 1),
        Uri.encodeComponent(secret),
        Uri.encodeQueryComponent(secret),
        // Submitted NZB URLs are encoded again inside the SABnzbd query.
        Uri.encodeComponent(Uri.encodeComponent(secret)),
        Uri.encodeComponent(Uri.encodeQueryComponent(secret)),
      ]);
    }
    final sortedValues = values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final value in sortedValues) {
      text = text.replaceAll(value, '***');
    }
    return text;
  }
}
