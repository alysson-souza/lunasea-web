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
    String method = 'DELETE',
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
      await dio.request(path, options: Options(method: method));
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

  for (final operation in ['rename', 'retry', 'addurl']) {
    for (final transport in [false, true]) {
      test('$operation secrets are redacted at the interceptor boundary '
          'for ${transport ? 'transport' : 'response'} failures', () async {
        const secret = 'synthetic +/=& credential';
        final encoded = Uri.encodeComponent(secret);
        final queryEncoded = Uri.encodeQueryComponent(secret);
        final query = switch (operation) {
          'rename' => {
            'mode': 'queue',
            'name': 'rename',
            'value': 'job-visible',
            'value2': 'job-name-visible',
            'value3': secret,
          },
          'retry' => {
            'mode': 'retry',
            'value': 'job-visible',
            'password': secret,
          },
          _ => {
            'mode': 'addurl',
            'name': Uri.https('indexer.test', '/getnzb', {
              'id': 'nzb-visible',
              'apikey': secret,
            }).toString(),
            'cat': 'category-visible',
          },
        };
        final adapter = _EchoingFailureAdapter(
          secret: secret,
          transport: transport,
        );
        final error = await failingRequest(
          baseUrl: 'https://sabnzbd.test/api',
          path: '',
          method: 'GET',
          queryParameters: query,
          adapter: adapter,
        );
        for (final text in [
          error.message!,
          error.toString(),
          error.stringBuilder!(error),
        ]) {
          for (final value in [
            secret,
            encoded,
            queryEncoded,
            Uri.encodeComponent(encoded),
            Uri.encodeComponent(queryEncoded),
          ]) {
            expect(
              text.contains(value),
              isFalse,
              reason: 'Readable errors must not expose a credential',
            );
          }
          expect(text, contains('GET https://sabnzbd.test/api'));
          expect(text, contains('upstream refused job'));
          expect(text, contains('***'));
          if (!transport) expect(text, contains('Status: 403'));
        }
        expect(error.requestOptions, same(adapter.requestOptions));
        if (operation == 'rename') {
          expect(error.requestOptions.queryParameters['value3'], secret);
          expect(error.message, contains('job-name-visible'));
        } else if (operation == 'retry') {
          expect(error.requestOptions.queryParameters['password'], secret);
        } else {
          expect(error.message, contains('indexer.test'));
          expect(error.message, contains('category-visible'));
        }
        if (operation != 'addurl') {
          expect(error.message, contains('job-visible'));
        }
        if (transport) {
          expect(error.error, same(adapter.cause));
          expect(error.error.toString(), contains('socket failure'));
          expect(error.toString(), contains('socket failure'));
          expect(error.stringBuilder!(error), contains('socket failure'));
        } else {
          expect(error.response?.statusCode, 403);
          expect(
            error.response?.data.toString().contains(secret),
            isTrue,
            reason: 'Only readable exception forms are redacted',
          );
        }
      });
    }
  }

  for (final transport in [false, true]) {
    test('JSON-escaped credentials are redacted in '
        '${transport ? 'causes' : 'response maps'}', () async {
      const secret = 'synthetic "quoted" \\ credential\n\t';
      final json = jsonEncode(secret);
      final escaped = json.substring(1, json.length - 1);
      final adapter = _EchoingFailureAdapter(
        secret: secret,
        transport: transport,
        jsonEchoCause: true,
      );
      final error = await failingRequest(
        baseUrl: 'https://sabnzbd.test/api',
        path: '',
        method: 'GET',
        queryParameters: {
          'mode': 'queue',
          'name': 'rename',
          'value': 'job-visible',
          'value3': secret,
        },
        adapter: adapter,
      );

      for (final text in [
        error.message!,
        error.toString(),
        error.stringBuilder!(error),
      ]) {
        for (final value in [
          secret,
          escaped,
          Uri.encodeComponent(secret),
          Uri.encodeQueryComponent(secret),
        ]) {
          expect(
            text.contains(value),
            isFalse,
            reason: 'Readable errors must not expose escaped credentials',
          );
        }
        expect(text, contains('GET https://sabnzbd.test/api'));
        expect(text, contains('job-visible'));
        expect(text, contains('upstream refused job'));
        if (!transport) expect(text, contains('Status: 403'));
      }
      expect(error.requestOptions, same(adapter.requestOptions));
      expect(error.requestOptions.queryParameters['value3'] == secret, isTrue);
      if (transport) {
        expect(error.error, same(adapter.cause));
        expect(error.error.toString(), contains('socket failure'));
        expect(error.toString(), contains('socket failure'));
        expect(error.stringBuilder!(error), contains('socket failure'));
        expect(error.error.toString().contains(escaped), isTrue);
      } else {
        expect(error.response?.statusCode, 403);
        expect(
          error.response?.data['error'].toString().contains(secret),
          isTrue,
        );
      }
    });
  }

  for (final credentialLocation in ['userinfo', 'path']) {
    for (final transport in [false, true]) {
      test('addurl nested $credentialLocation credentials are redacted '
          'for ${transport ? 'transport' : 'response'} failures', () async {
        const username = 'synthetic-nested-user';
        const password = 'synthetic nested+&=password';
        const credentials = '$username:$password';
        final nestedUrl = Uri(
          scheme: 'https',
          userInfo: credentialLocation == 'userinfo' ? credentials : '',
          host: 'indexer.test',
          path: credentialLocation == 'path'
              ? '/$credentials/getnzb'
              : '/getnzb',
          queryParameters: {'id': 'nzb-visible'},
        ).toString();
        final adapter = _EchoingFailureAdapter(
          secret: credentials,
          transport: transport,
          additionalEchoes: [
            nestedUrl,
            Uri.encodeComponent(nestedUrl),
            Uri.decodeComponent(nestedUrl),
          ],
        );
        final error = await failingRequest(
          baseUrl: 'https://sabnzbd.test/api',
          path: '',
          method: 'GET',
          queryParameters: {
            'mode': 'addurl',
            'name': nestedUrl,
            'cat': 'category-visible',
          },
          adapter: adapter,
        );
        for (final text in [
          error.message!,
          error.toString(),
          error.stringBuilder!(error),
        ]) {
          for (final secret in [username, password, credentials]) {
            for (final encoded in [
              secret,
              Uri.encodeComponent(secret),
              Uri.encodeQueryComponent(secret),
              Uri.encodeComponent(Uri.encodeComponent(secret)),
              Uri.encodeComponent(Uri.encodeQueryComponent(secret)),
            ]) {
              expect(
                text.contains(encoded),
                isFalse,
                reason: 'Nested URL credentials must not reach readable errors',
              );
            }
          }
          expect(text, contains('GET https://sabnzbd.test/api'));
          expect(text, contains('indexer.test'));
          expect(text, contains('nzb-visible'));
          expect(text, contains('category-visible'));
          expect(text, contains('upstream refused job'));
          expect(text, contains('***'));
          if (!transport) expect(text, contains('Status: 403'));
        }
        expect(error.requestOptions, same(adapter.requestOptions));
        expect(error.requestOptions.queryParameters['name'], nestedUrl);
        if (transport) {
          expect(error.error, same(adapter.cause));
          expect(error.error.toString(), contains(credentials));
          expect(error.toString(), contains('socket failure'));
          expect(error.stringBuilder!(error), contains('socket failure'));
        } else {
          expect(error.response?.statusCode, 403);
          expect(error.response?.data['error'], contains(nestedUrl));
        }
      });
    }
  }

  for (final credentialLocation in ['userinfo', 'path']) {
    for (final transport in [false, true]) {
      test('mixed serialized addurl $credentialLocation credentials are redacted '
          'for ${transport ? 'transport' : 'response'} failures', () async {
        const username = 'serialized-user';
        const serializedPassword = 'mixed%20words+plus%2Fpart&equals=tail';
        final password = Uri.decodeComponent(serializedPassword);
        final separator = credentialLocation == 'userinfo' ? ':' : '%3A';
        final serializedCredentials = '$username$separator$serializedPassword';
        final nestedUrl = credentialLocation == 'userinfo'
            ? 'https://$serializedCredentials@indexer.test/getnzb?id=nzb-visible'
            : 'https://indexer.test/$serializedCredentials/getnzb?id=nzb-visible';
        final adapter = _EchoingFailureAdapter(
          secret: serializedPassword,
          transport: transport,
          additionalEchoes: [
            password,
            Uri.encodeComponent(password),
            Uri.encodeQueryComponent(password),
            nestedUrl,
            Uri.encodeComponent(nestedUrl),
            Uri.decodeComponent(nestedUrl),
          ],
        );
        final error = await failingRequest(
          baseUrl: 'https://sabnzbd.test/api',
          path: '',
          method: 'GET',
          queryParameters: {
            'mode': 'addurl',
            'name': nestedUrl,
            'cat': 'category-visible',
          },
          adapter: adapter,
        );

        for (final text in [
          error.message!,
          error.toString(),
          error.stringBuilder!(error),
        ]) {
          for (final secret in [
            username,
            serializedPassword,
            password,
            serializedCredentials,
          ]) {
            final json = jsonEncode(secret);
            for (final variant in [
              secret,
              json.substring(1, json.length - 1),
              Uri.encodeComponent(secret),
              Uri.encodeQueryComponent(secret),
              Uri.encodeComponent(Uri.encodeComponent(secret)),
              Uri.encodeComponent(Uri.encodeQueryComponent(secret)),
            ]) {
              expect(
                text.contains(variant),
                isFalse,
                reason: 'Serialized credentials must not reach readable errors',
              );
            }
          }
          expect(text, contains('GET https://sabnzbd.test/api'));
          expect(text, contains('indexer.test'));
          expect(text, contains('nzb-visible'));
          expect(text, contains('category-visible'));
          expect(text, contains('upstream refused job'));
          expect(text, contains('***'));
          if (!transport) expect(text, contains('Status: 403'));
        }
        expect(error.requestOptions, same(adapter.requestOptions));
        expect(
          error.requestOptions.queryParameters['name'] == nestedUrl,
          isTrue,
        );
        if (transport) {
          expect(error.error, same(adapter.cause));
          expect(error.error.toString().contains(serializedPassword), isTrue);
          expect(error.toString(), contains('socket failure'));
          expect(error.stringBuilder!(error), contains('socket failure'));
        } else {
          expect(error.response?.statusCode, 403);
          expect(
            error.response?.data['error'].toString().contains(
              serializedPassword,
            ),
            isTrue,
          );
          expect(
            error.response?.data['error'].toString().contains(nestedUrl),
            isTrue,
          );
        }
      });
    }
  }

  test('ordinary positional values and diagnostics remain readable', () async {
    final error = await failingRequest(
      baseUrl: 'https://sabnzbd.test/api',
      path: '',
      method: 'GET',
      queryParameters: {
        'mode': 'queue',
        'name': 'change_cat',
        'value': 'job-visible',
        'value3': 'category-visible',
      },
      adapter: _NotFoundAdapter(
        body: 'job-visible category-visible useful diagnostic',
        json: false,
      ),
    );
    for (final value in [
      'job-visible',
      'category-visible',
      'useful diagnostic',
    ]) {
      expect(error.message, contains(value));
      expect(error.toString(), contains(value));
    }
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

class _EchoingFailureAdapter implements HttpClientAdapter {
  _EchoingFailureAdapter({
    required this.secret,
    required this.transport,
    this.jsonEchoCause = false,
    this.additionalEchoes = const [],
  });

  final String secret;
  final bool transport;
  final bool jsonEchoCause;
  final List<String> additionalEchoes;
  RequestOptions? requestOptions;
  Object? cause;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    final encoded = Uri.encodeComponent(secret);
    final queryEncoded = Uri.encodeQueryComponent(secret);
    final echoes = [
      'upstream refused job',
      secret,
      encoded,
      queryEncoded,
      Uri.encodeComponent(encoded),
      Uri.encodeComponent(queryEncoded),
      options.uri.toString(),
      ...additionalEchoes,
    ].join(' | ');
    if (transport) {
      final causeEcho = jsonEchoCause ? jsonEncode({'error': echoes}) : echoes;
      cause = StateError('socket failure $causeEcho');
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: echoes,
        error: cause,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'error': echoes}),
      403,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
