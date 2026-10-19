import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/api/api.dart';

void main() {
  late HttpServer server;
  late StreamSubscription<HttpRequest> requestsSubscription;
  late SABnzbdAPI api;
  late Map<String, dynamic> response;
  late List<Uri> requests;

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requestsSubscription = server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    api = SABnzbdAPI.fromInstance(
      LunaServiceInstance(
        id: 'local-sabnzbd',
        module: LunaModule.SABNZBD,
        enabled: true,
        host: 'http://${server.address.address}:${server.port}',
        apiKey: 'fixture-key',
      ),
    );
  });

  tearDown(() async {
    await server.close(force: true);
    await requestsSubscription.cancel();
  });

  test(
    'queue decodes mixed numeric values and preserves page metadata',
    () async {
      for (final stringSpeed in [false, true]) {
        response = {
          'queue': {
            'paused': true,
            'kbpersec': stringSpeed ? '1024.5' : 1024.5,
            'mbleft': stringSpeed ? 512.25 : '512.25',
            'timeleft': '00:08:32',
            'speedlimit': stringSpeed ? 75 : '75',
            'noofslots': stringSpeed ? 37 : '37',
            'start': stringSpeed ? '6' : 6,
            'limit': stringSpeed ? 2 : '2',
            'slots': [
              {
                'nzo_id': 'queue-first',
                'filename': 'First download',
                'mb': 1536.4,
                'mbleft': '384.2',
                'status': 'Paused',
                'timeleft': '00:06:00',
                'cat': '*',
              },
              {
                'nzo_id': 'queue-second',
                'filename': 'Second download',
                'mb': '256.6',
                'mbleft': 64.8,
                'status': 'Downloading',
                'timeleft': '00:01:00',
                'cat': 'tv',
              },
            ],
          },
        };

        final snapshot = await api.getQueue(start: 4, limit: 5);

        expect(snapshot.total, 37);
        expect(snapshot.start, 6);
        expect(snapshot.limit, 2);
        expect(snapshot.status.paused, isTrue);
        expect(snapshot.status.speed, 1024.5);
        expect(snapshot.status.sizeLeft, 512.25);
        expect(snapshot.status.timeLeft, '00:08:32');
        expect(snapshot.status.speedlimit, 75);
        expect(snapshot.items, hasLength(2));
        final first = snapshot.items.first;
        expect(first.nzoId, 'queue-first');
        expect(first.name, 'First download');
        expect(first.sizeTotal, 1536);
        expect(first.sizeLeft, 384);
        expect(first.status, 'Paused');
        expect(first.isPaused, isTrue);
        expect(first.timeLeft, '00:06:00');
        expect(first.formattedCategory, 'Default');
        final second = snapshot.items.last;
        expect(second.nzoId, 'queue-second');
        expect(second.name, 'Second download');
        expect(second.sizeTotal, 257);
        expect(second.sizeLeft, 65);
        expect(second.status, 'Downloading');
        expect(second.isPaused, isFalse);
        expect(second.category, 'tv');
        expect(requests.last.path, '/api');
        expect(requests.last.queryParameters, containsPair('mode', 'queue'));
        expect(requests.last.queryParameters, containsPair('start', '4'));
        expect(requests.last.queryParameters, containsPair('limit', '5'));
      }
      expect(requests, hasLength(2));
    },
  );

  test(
    'history decodes completed times, bytes and pagination totals',
    () async {
      response = {
        'history': {
          'noofslots': '23',
          'slots': [
            {
              'nzo_id': 'history-completed',
              'name': 'Completed download',
              'bytes': '2147483648',
              'completed': '1720000123',
              'download_time': '120',
              'status': 'Completed',
              'fail_message': '',
              'action_line': '',
              'category': '*',
              'storage': '/downloads/completed',
              'stage_log': [
                {
                  'name': 'Download',
                  'actions': ['Downloaded in 2 minutes'],
                },
              ],
            },
            {
              'nzo_id': 'history-failed',
              'name': 'Failed download',
              'bytes': 536870912,
              'completed': 1720000223,
              'download_time': 45,
              'status': 'Failed',
              'fail_message': 'Repair failed',
              'action_line': '',
              'category': 'tv',
              'storage': '/downloads/incomplete',
              'stage_log': [],
            },
          ],
        },
      };

      final page = await api.getHistoryPage(start: 6, limit: 2);

      expect(page.total, 23);
      expect(page.start, 6);
      expect(page.limit, 2);
      expect(page.items, hasLength(2));
      final completed = page.items.first;
      expect(completed.nzoId, 'history-completed');
      expect(completed.name, 'Completed download');
      expect(completed.size, 2147483648);
      expect(completed.timestamp, 1720000123);
      expect(
        completed.completeTimeObject.millisecondsSinceEpoch,
        1720000123000,
      );
      expect(completed.downloadTime, 120);
      expect(completed.status, 'Completed');
      expect(completed.failed, isFalse);
      expect(completed.category, 'Default');
      expect(completed.storageLocation, '/downloads/completed');
      expect(completed.stageLog, [
        {
          'name': 'Download',
          'actions': ['Downloaded in 2 minutes'],
        },
      ]);
      final failed = page.items.last;
      expect(failed.nzoId, 'history-failed');
      expect(failed.size, 536870912);
      expect(failed.timestamp, 1720000223);
      expect(failed.downloadTime, 45);
      expect(failed.status, 'Failed');
      expect(failed.failed, isTrue);
      expect(failed.failureMessage, 'Repair failed');
      expect(failed.category, 'tv');
      expect(requests.single.queryParameters, containsPair('mode', 'history'));
      expect(requests.single.queryParameters, containsPair('start', '6'));
      expect(requests.single.queryParameters, containsPair('limit', '2'));
    },
  );

  test('history lookup requests and decodes the exact item by ID', () async {
    response = {
      'history': {
        'slots': [
          {'nzo_id': 'unrelated-history', 'name': 'Unrelated download'},
          {
            'nzo_id': 'requested-history',
            'name': 'Requested download',
            'bytes': '2147483648',
            'completed': '1720000123',
            'download_time': '120',
            'status': 'Failed',
            'fail_message': 'Repair failed',
            'action_line': 'Repairing',
            'category': '*',
            'storage': '/downloads/requested',
            'stage_log': [
              {
                'name': 'Repair',
                'actions': ['Repair failed'],
              },
            ],
          },
        ],
      },
    };

    final item = await api.getHistoryItem('requested-history');

    expect(item, isNotNull);
    expect(item!.nzoId, 'requested-history');
    expect(item.name, 'Requested download');
    expect(item.size, 2147483648);
    expect(item.timestamp, 1720000123);
    expect(item.downloadTime, 120);
    expect(item.status, 'Failed');
    expect(item.failureMessage, 'Repair failed');
    expect(item.actionLine, 'Repairing');
    expect(item.category, 'Default');
    expect(item.storageLocation, '/downloads/requested');
    expect(item.stageLog, [
      {
        'name': 'Repair',
        'actions': ['Repair failed'],
      },
    ]);
    expect(requests.single.queryParameters, containsPair('mode', 'history'));
    expect(
      requests.single.queryParameters,
      containsPair('nzo_ids', 'requested-history'),
    );
    expect(requests.single.queryParameters.containsKey('start'), isFalse);
  });

  test('history lookup returns null only when the item is absent', () async {
    response = {
      'history': {'slots': []},
    };
    expect(await api.getHistoryItem('missing-history'), isNull);

    response = {
      'history': {
        'slots': [
          {'nzo_id': 'different-history', 'name': 'Different download'},
        ],
      },
    };
    expect(await api.getHistoryItem('missing-history'), isNull);
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(
        request.queryParameters,
        containsPair('nzo_ids', 'missing-history'),
      );
    }

    response = {
      'history': {
        'slots': [
          {'nzo_id': 'missing-history', 'bytes': 'invalid-number'},
        ],
      },
    };
    await expectLater(
      api.getHistoryItem('missing-history'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'API error JSON rejects queue and history instead of empty success',
    () async {
      response = {'status': false, 'error': 'API key incorrect'};
      final apiError = throwsA(
        predicate<Object>(
          (error) => error.toString().contains('API key incorrect'),
          'an error containing the SABnzbd API error message',
        ),
      );

      await expectLater(api.getQueue(), apiError);
      await expectLater(api.getHistoryPage(), apiError);
      await expectLater(api.getHistoryItem('requested-history'), apiError);

      expect(requests.map((request) => request.queryParameters['mode']), [
        'queue',
        'history',
        'history',
      ]);
    },
  );

  test(
    'mutation false status is retained, including priority changes',
    () async {
      response = {'status': false};

      expect(await api.pauseQueue(), isFalse);
      expect(await api.setJobPriority('queue-first', 2), isFalse);

      response = {'status': true};
      expect(await api.setJobPriority('queue-first', 1), isTrue);
      expect(requests, hasLength(3));
      expect(requests.first.queryParameters, containsPair('mode', 'pause'));
      expect(requests[1].queryParameters, containsPair('name', 'priority'));
      expect(requests[1].queryParameters, containsPair('value', 'queue-first'));
      expect(requests[1].queryParameters, containsPair('value2', '2'));
    },
  );
}
