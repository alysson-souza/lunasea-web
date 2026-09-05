import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/system/network/dio_error_interceptor.dart';

void main() {
  Future<DioException> failingRequest({
    required String baseUrl,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    String path = 'episodefile/10796',
    HttpClientAdapter? adapter,
  }) async {
    final dio =
        Dio(
            BaseOptions(
              baseUrl: baseUrl,
              queryParameters: queryParameters,
              headers: headers,
            ),
          )
          ..httpClientAdapter = adapter ?? _NotFoundAdapter()
          ..interceptors.add(const LunaDioErrorInterceptor());
    try {
      await dio.delete(path);
    } on DioException catch (error) {
      return error;
    }
    fail('expected the request to fail');
  }

  test(
    'toString identifies the method, URL, status, and response body',
    () async {
      final error = await failingRequest(
        baseUrl: 'https://sonarr.test/api/v3/',
        adapter: _NotFoundAdapter(
          body: jsonEncode({'errorMessage': 'Not found'}),
        ),
      );
      final text = error.toString();
      expect(
        text,
        contains('DELETE https://sonarr.test/api/v3/episodefile/10796'),
      );
      expect(text, contains('Status: 404'));
      expect(text, contains('Not found'));
    },
  );

  test('the api key never appears in the message', () async {
    final error = await failingRequest(
      baseUrl: 'https://sonarr.test/api/v3/',
      queryParameters: {'apikey': 'supersecret-key'},
      adapter: _NotFoundAdapter(
        body: jsonEncode({'errorMessage': 'invalid apikey supersecret-key'}),
      ),
    );
    final text = error.toString();
    expect(text, contains('episodefile/10796'));
    expect(text, contains('***'));
    expect(text, isNot(contains('supersecret-key')));
  });

  test(
    'the exception and response stay intact for existing handlers',
    () async {
      final error = await failingRequest(
        baseUrl: 'https://sonarr.test/api/v3/',
        adapter: _NotFoundAdapter(
          body: jsonEncode({'errorMessage': 'Not found'}),
        ),
      );
      expect(error.type, DioExceptionType.badResponse);
      expect(error.response?.statusCode, 404);
      expect(error.requestOptions.method, 'DELETE');
    },
  );

  test('redacts API keys from URL queries and echoed headers', () async {
    final error = await failingRequest(
      baseUrl: 'https://sonarr.test/api/v3/',
      path: 'episodefile/10796?ApiKey=url-secret',
      headers: {'X-Api-Key': 'header-secret'},
      adapter: _NotFoundAdapter(body: 'url-secret header-secret', json: false),
    );
    expect(error.toString(), isNot(contains('url-secret')));
    expect(error.toString(), isNot(contains('header-secret')));
    expect(error.toString(), contains('Status: 404'));
  });

  test('oversized response bodies are truncated', () async {
    final error = await failingRequest(
      baseUrl: 'https://sonarr.test/api/v3/',
      adapter: _NotFoundAdapter(body: 'x' * 10000, json: false),
    );
    expect(error.toString().length, lessThan(10000));
    expect(error.toString(), contains('…'));
  });

  test('credentials embedded in the URL path never appear', () async {
    final error = await failingRequest(
      baseUrl: 'https://nzbget.test/secretuser:secretpass/jsonrpc/',
    );
    final text = error.toString();
    expect(text, contains('https://nzbget.test/***/jsonrpc/episodefile/10796'));
    expect(text, isNot(contains('secretuser')));
    expect(text, isNot(contains('secretpass')));
  });

  test('userinfo credentials never appear', () async {
    final error = await failingRequest(
      baseUrl: 'https://secretuser:secretpass@nzbget.test/jsonrpc/',
    );
    final text = error.toString();
    expect(text, contains('***@nzbget.test'));
    expect(text, isNot(contains('secretuser')));
    expect(text, isNot(contains('secretpass')));
  });

  test('non-response errors keep their original diagnostic', () async {
    final error = await failingRequest(
      baseUrl: 'https://sonarr.test/api/v3/',
      adapter: _ThrowingAdapter(),
    );
    expect(error.type, isNot(DioExceptionType.badResponse));
    expect(error.toString(), contains('socket boom'));
    expect(
      error.toString(),
      contains('DELETE https://sonarr.test/api/v3/episodefile/10796'),
    );
  });

  test('transport errors do not expose credentials in their cause', () async {
    final error = await failingRequest(
      baseUrl: 'https://secretuser:secretpass@sonarr.test/api/v3/',
      queryParameters: {'apikey': 'transport-secret'},
      adapter: _ThrowingAdapter(echoUri: true),
    );
    expect(error.toString(), contains('socket boom'));
    for (final secret in ['secretuser', 'secretpass', 'transport-secret']) {
      expect(error.toString(), isNot(contains(secret)));
    }
    expect(error.error, isA<Exception>());
  });
}

class _NotFoundAdapter implements HttpClientAdapter {
  _NotFoundAdapter({
    this.body = '{"errorMessage": "Not Found"}',
    this.json = true,
  });

  final String body;
  final bool json;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    404,
    headers: {
      Headers.contentTypeHeader: [
        json ? Headers.jsonContentType : Headers.textPlainContentType,
      ],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter({this.echoUri = false});
  final bool echoUri;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw Exception('socket boom${echoUri ? ' ${options.uri}' : ''}');

  @override
  void close({bool force = false}) {}
}
