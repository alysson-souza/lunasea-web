import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/system/gateway/gateway.dart';

void main() {
  test(
    'client exports and imports configuration through backend config API',
    () async {
      final adapter = _ConfigAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://lunasea.test/_lunasea/api/'))
        ..httpClientAdapter = adapter;
      final client = LunaBackendClient(dio: dio);

      final exported = await client.exportConfiguration();
      final state = await client.importConfiguration(
        utf8.encode('{"format":"lunasea-web-config","version":1}'),
      );

      expect(
        utf8.decode(exported),
        '{"format":"lunasea-web-config","version":1}',
      );
      expect(state['gateway'], isTrue);
      expect(adapter.requests, ['GET config/export', 'POST config/import']);
      expect(
        utf8.decode(adapter.importBody),
        '{"format":"lunasea-web-config","version":1}',
      );
    },
  );
}

class _ConfigAdapter implements HttpClientAdapter {
  final requests = <String>[];
  List<int> importBody = const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    if (options.path == 'config/export' && options.method == 'GET') {
      return ResponseBody.fromString(
        '{"format":"lunasea-web-config","version":1}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == 'config/import' && options.method == 'POST') {
      final chunks = await (requestStream ?? const Stream<Uint8List>.empty())
          .toList();
      importBody = chunks.expand((chunk) => chunk).toList();
      return ResponseBody.fromString(
        '{"gateway":true,"serviceInstances":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('not found', 404);
  }

  @override
  void close({bool force = false}) {}
}
