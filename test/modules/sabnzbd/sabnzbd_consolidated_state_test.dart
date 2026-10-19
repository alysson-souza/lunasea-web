import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/snapshot.dart';
import 'package:lunasea/modules/sabnzbd/core/consolidated_state.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';

void main() {
  group('SABnzbdConsolidatedState', () {
    test(
      'history retains colliding IDs and sorts by time, owner key, then job ID',
      () async {
        final fixture = _AggregateFixture();

        await fixture.aggregate.refreshHistory();

        expect(_historyKeys(fixture.aggregate), [
          'default:sabnzbd:a/newest',
          'default:sabnzbd:a/a-tie',
          'default:sabnzbd:a/shared',
          'default:sabnzbd:a/z-tie',
          'default:sabnzbd:z/shared',
          'default:sabnzbd:z/older',
        ]);
        expect(
          fixture.aggregate.history
              .where((entry) => entry.item.nzoId == 'shared')
              .map((entry) => entry.item.name),
          ['Alpha pack', 'Episode ALPHA'],
        );
        expect(fixture.aState.history.length, 4);
        expect(fixture.zState.history.length, 2);
      },
    );

    test(
      'title search and failed-only filters combine without changing source filters',
      () async {
        final fixture = _AggregateFixture();
        fixture.aState.historySearchFilter = 'source a filter';
        fixture.zState.historySearchFilter = 'source z filter';
        await fixture.aggregate.refreshHistory();

        fixture.aggregate.historySearchFilter = 'ALPHA';
        expect(_historyKeys(fixture.aggregate), [
          'default:sabnzbd:a/a-tie',
          'default:sabnzbd:a/shared',
          'default:sabnzbd:z/shared',
          'default:sabnzbd:z/older',
        ]);

        fixture.aggregate.historyFailedOnly = true;
        expect(_historyKeys(fixture.aggregate), [
          'default:sabnzbd:a/a-tie',
          'default:sabnzbd:z/shared',
        ]);
        expect(fixture.aState.historySearchFilter, 'source a filter');
        expect(fixture.zState.historySearchFilter, 'source z filter');
        expect(fixture.aState.history.length, 4);
        expect(fixture.zState.history.length, 2);

        fixture.aggregate.historySearchFilter = '';
        expect(_historyKeys(fixture.aggregate), [
          'default:sabnzbd:a/a-tie',
          'default:sabnzbd:a/z-tie',
          'default:sabnzbd:z/shared',
        ]);
        fixture.aggregate.historyFailedOnly = false;
        expect(fixture.aggregate.history.length, 6);
      },
    );

    test(
      'history search matches titles rather than category or failure text',
      () async {
        final fixture = _AggregateFixture();
        await fixture.aggregate.refreshHistory();

        fixture.aggregate.historySearchFilter = 'category-only';
        expect(fixture.aggregate.history, isEmpty);
        fixture.aggregate.historySearchFilter = 'failure-only';
        expect(fixture.aggregate.history, isEmpty);
        fixture.aggregate.historySearchFilter = 'no matching title';
        expect(fixture.aggregate.history, isEmpty);
      },
    );

    test(
      'a successful source publishes while another retains its last good snapshot during refresh',
      () async {
        final fixture = _AggregateFixture();
        await fixture.aggregate.refreshQueue();
        final previousStatus = fixture.zState.status;
        final previousQueue = fixture.zState.queue;
        final pending = Completer<SABnzbdQueueSnapshot>();
        final started = Completer<void>();
        fixture.zApi.pendingQueue = pending;
        fixture.zApi.queueStarted = started;
        fixture.aApi.speed = 5;
        fixture.aApi.sizeLeft = 7;
        final aPublished = Completer<void>();
        void onAggregateChanged() {
          if (!aPublished.isCompleted && fixture.aState.status?.speed == 5) {
            aPublished.complete();
          }
        }

        fixture.aggregate.addListener(onAggregateChanged);

        final refresh = fixture.aggregate.refreshQueue();
        await started.future.timeout(const Duration(seconds: 1));
        await aPublished.future.timeout(const Duration(seconds: 1));

        final pendingLoading = fixture.zState.queueLoading;
        final pendingStatus = fixture.zState.status;
        final pendingQueue = fixture.zState.queue;
        final publishedStatus = fixture.aState.status;
        pending.complete(fixture.zApi.snapshot());
        await refresh;
        fixture.aggregate.removeListener(onAggregateChanged);

        expect(pendingLoading, isTrue);
        expect(pendingStatus, same(previousStatus));
        expect(pendingQueue, same(previousQueue));
        expect(publishedStatus!.speed, 5);
        expect(publishedStatus.sizeLeft, 7);
        expect(fixture.zState.status!.speed, 1.5);
        expect(fixture.zState.queue.single.nzoId, 'shared');
      },
    );

    test(
      'a source without an initial snapshot remains unavailable while loading',
      () async {
        final fixture = _AggregateFixture();
        final pending = Completer<SABnzbdQueueSnapshot>();
        final started = Completer<void>();
        fixture.zApi.pendingQueue = pending;
        fixture.zApi.queueStarted = started;
        final aPublished = Completer<void>();
        void onAggregateChanged() {
          if (!aPublished.isCompleted && fixture.aState.status != null) {
            aPublished.complete();
          }
        }

        fixture.aggregate.addListener(onAggregateChanged);
        final refresh = fixture.aggregate.refreshQueue();
        await started.future.timeout(const Duration(seconds: 1));
        await aPublished.future.timeout(const Duration(seconds: 1));

        final pendingLoading = fixture.zState.queueLoading;
        final pendingStatus = fixture.zState.status;
        final publishedStatus = fixture.aState.status;
        pending.complete(fixture.zApi.snapshot());
        await refresh;
        fixture.aggregate.removeListener(onAggregateChanged);

        expect(pendingLoading, isTrue);
        expect(pendingStatus, isNull);
        expect(publishedStatus!.speed, 2.25);
        expect(publishedStatus.sizeLeft, 1.25);
        expect(fixture.zState.status!.speed, 1.5);
        expect(fixture.zState.queue.single.nzoId, 'shared');
      },
    );

    test(
      'direct source refresh notifies aggregate listeners and updates history',
      () async {
        final fixture = _AggregateFixture();
        await fixture.aggregate.refreshHistory();
        final published = <List<String>>[];
        fixture.aggregate.addListener(() {
          published.add(_historyKeys(fixture.aggregate));
        });
        fixture.aApi.records = [_history('replacement', 'Replacement', 50)];

        await fixture.aState.refreshHistory();

        expect(_historyKeys(fixture.aggregate), [
          'default:sabnzbd:a/replacement',
          'default:sabnzbd:z/shared',
          'default:sabnzbd:z/older',
        ]);
        expect(
          published,
          contains(
            equals([
              'default:sabnzbd:a/replacement',
              'default:sabnzbd:z/shared',
              'default:sabnzbd:z/older',
            ]),
          ),
        );
      },
    );

    test(
      'disposing the aggregate releases listeners without disposing borrowed sources',
      () async {
        final fixture = _AggregateFixture();
        await fixture.aggregate.refreshHistory();
        var notifications = 0;
        fixture.aggregate.addListener(() => notifications++);
        fixture.aggregate.dispose();
        fixture.aggregateDisposed = true;
        final afterDispose = notifications;
        fixture.aApi.records = [_history('after-dispose', 'After dispose', 60)];

        await fixture.aState.refreshHistory();

        expect(fixture.aState.isDisposed, isFalse);
        expect(fixture.zState.isDisposed, isFalse);
        expect(fixture.aState.history.single.nzoId, 'after-dispose');
        expect(notifications, afterDispose);
      },
    );
  });
}

List<String> _historyKeys(SABnzbdConsolidatedState aggregate) => aggregate
    .history
    .map((entry) => '${entry.instance.ref.key}/${entry.item.nzoId}')
    .toList();

class _AggregateFixture {
  final LunaServiceInstance a = _instance('a');
  final LunaServiceInstance z = _instance('z');
  late final _AggregateAPI aApi = _AggregateAPI(
    speed: 2.25,
    sizeLeft: 1.25,
    records: [
      _history('z-tie', 'Other title', 30, failed: true),
      _history('shared', 'Alpha pack', 30),
      _history('newest', 'Beta newest', 40),
      _history('a-tie', 'alpha failed', 30, failed: true),
    ],
  );
  late final _AggregateAPI zApi = _AggregateAPI(
    speed: 1.5,
    sizeLeft: 2.5,
    records: [
      _history('older', 'alpha complete', 10),
      _history('shared', 'Episode ALPHA', 30, failed: true),
    ],
  );
  late final SABnzbdState aState = SABnzbdState(instance: a, apiClient: aApi);
  late final SABnzbdState zState = SABnzbdState(instance: z, apiClient: zApi);
  late final SABnzbdConsolidatedState aggregate = SABnzbdConsolidatedState(
    instances: [z, a],
    instanceStates: [zState, aState],
  );
  bool aggregateDisposed = false;

  _AggregateFixture() {
    addTearDown(() {
      if (!aggregateDisposed) aggregate.dispose();
      aState.dispose();
      zState.dispose();
    });
  }
}

LunaServiceInstance _instance(String id) => LunaServiceInstance(
  id: id,
  profileId: 'default',
  module: LunaModule.SABNZBD,
  enabled: true,
  host: 'https://$id.example/',
  apiKey: '$id-key',
);

SABnzbdHistoryData _history(
  String id,
  String name,
  int timestamp, {
  bool failed = false,
}) => SABnzbdHistoryData(
  nzoId: id,
  name: name,
  size: 1024,
  status: failed ? 'Failed' : 'Completed',
  failureMessage: failed ? 'failure-only' : '',
  timestamp: timestamp,
  actionLine: '',
  category: 'category-only',
  downloadTime: 1,
  stageLog: [],
  storageLocation: '/downloads/$id',
);

class _AggregateAPI implements SABnzbdAPI {
  double speed;
  double sizeLeft;
  List<SABnzbdHistoryData> records;
  Completer<SABnzbdQueueSnapshot>? pendingQueue;
  Completer<void>? queueStarted;

  _AggregateAPI({
    required this.speed,
    required this.sizeLeft,
    required this.records,
  });

  SABnzbdQueueSnapshot snapshot({int start = 0, int limit = 100}) =>
      SABnzbdQueueSnapshot(
        status: SABnzbdStatusData(
          paused: false,
          speed: speed,
          sizeLeft: sizeLeft,
          timeLeft: '0:01:00',
          speedlimit: 0,
        ),
        items: [
          SABnzbdQueueData(
            nzoId: 'shared',
            name: 'Same job ID on two servers',
            sizeTotal: 10,
            sizeLeft: 5,
            status: 'Downloading',
            timeLeft: '0:01:00',
            category: '*',
          ),
        ],
        total: 1,
        start: start,
        limit: limit,
      );

  @override
  Future<SABnzbdQueueSnapshot> getQueue({
    int start = 0,
    int limit = 100,
  }) async {
    final started = queueStarted;
    if (started != null && !started.isCompleted) started.complete();
    final pending = pendingQueue;
    if (pending != null) {
      pendingQueue = null;
      return pending.future;
    }
    return snapshot(start: start, limit: limit);
  }

  @override
  Future<SABnzbdHistoryPage> getHistoryPage({
    int start = 0,
    int limit = 200,
  }) async => SABnzbdHistoryPage(
    items: List<SABnzbdHistoryData>.of(records),
    total: records.length,
    start: start,
    limit: limit,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
