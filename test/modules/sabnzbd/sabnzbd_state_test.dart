import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/snapshot.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';

void main() {
  testWidgets(
    'snapshots retain numeric status and publish collections independently',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(apiClient: api);
      addTearDown(state.dispose);

      final queue = state.refreshQueue();
      final sameQueue = state.refreshQueue();
      final history = state.refreshHistory();
      await tester.pump();

      expect(api.queueRequests, hasLength(1));
      expect(api.historyRequests, hasLength(1));
      expect(state.queueLoading, isTrue);
      expect(state.historyLoading, isTrue);

      api.historyRequests.single.complete(_historyPage([_history('finished')]));
      await tester.pump();
      await history;
      expect(state.history.map((item) => item.nzoId), ['finished']);
      expect(state.historyLoading, isFalse);
      expect(state.historyUpdatedAt, isNotNull);
      expect(state.queueLoading, isTrue);
      expect(state.status, isNull);

      api.queueRequests.single.complete(
        _queueSnapshot(
          [_queue('downloading')],
          total: 321,
          speed: 1536.75,
          sizeLeft: 8192.5,
        ),
      );
      await tester.pump();
      await Future.wait([queue, sameQueue]);

      expect(state.status!.speed, 1536.75);
      expect(state.status!.sizeLeft, 8192.5);
      expect(state.status!.paused, isFalse);
      expect(state.status!.timeLeft, '0:05:00');
      expect(state.status!.speedlimit, 75);
      expect(state.queue.map((item) => item.nzoId), ['downloading']);
      expect(state.queueTotal, 321);
      expect(state.hasMoreQueue, isTrue);
      expect(state.queueLoading, isFalse);
      expect(state.queueError, isNull);
      expect(state.queueStale, isFalse);
      expect(state.queueUpdatedAt, isNotNull);
    },
  );

  testWidgets('queue Load More grows the prefix and refresh replaces it', (
    tester,
  ) async {
    final api = _ControlledAPI();
    final state = SABnzbdState(apiClient: api);
    addTearDown(state.dispose);
    final first = List.generate(100, (index) => _queue('job-$index'));
    final expanded = List.generate(200, (index) => _queue('job-$index'));

    final initial = state.refreshQueue();
    await tester.pump();
    expect(api.queueRequests.last.start, 0);
    expect(api.queueRequests.last.limit, 100);
    api.queueRequests.last.complete(_queueSnapshot(first, total: 250));
    await tester.pump();
    await initial;

    final more = state.loadMoreQueue();
    await tester.pump();
    expect(api.queueRequests.last.start, 0);
    expect(api.queueRequests.last.limit, 200);
    api.queueRequests.last.complete(
      _queueSnapshot(expanded, total: 250, limit: 200),
    );
    await tester.pump();
    await more;
    expect(state.queue, hasLength(200));
    expect(state.queue.map((item) => item.nzoId).toSet(), hasLength(200));
    expect(state.hasMoreQueue, isTrue);

    final refreshed = [_queue('new-first'), ...expanded.take(199)];
    final refresh = state.refreshQueue();
    await tester.pump();
    expect(api.queueRequests.last.start, 0);
    expect(api.queueRequests.last.limit, 200);
    api.queueRequests.last.complete(
      _queueSnapshot(refreshed, total: 200, limit: 200),
    );
    await tester.pump();
    await refresh;

    expect(state.queue.map((item) => item.nzoId), [
      'new-first',
      ...List.generate(199, (index) => 'job-$index'),
    ]);
    expect(state.queueTotal, 200);
    expect(state.hasMoreQueue, isFalse);
    await state.loadMoreQueue();
    expect(api.queueRequests, hasLength(3));
  });

  testWidgets(
    'history Load More refetches the prefix after deletion at the page boundary',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(apiClient: api);
      addTearDown(state.dispose);

      final initial = state.refreshHistory();
      api.historyRequests.last.complete(
        _historyPage(
          List.generate(200, (index) => _history('job-$index')),
          total: 401,
        ),
      );
      await tester.pump();
      await initial;

      final more = state.loadMoreHistory();
      await tester.pump();
      expect(api.historyRequests.last.start, 0);
      expect(api.historyRequests.last.limit, 400);
      api.historyRequests.last.complete(
        _historyPage(
          List.generate(400, (index) => _history('job-${index + 1}')),
          total: 400,
          limit: 400,
        ),
      );
      await tester.pump();
      await more;

      expect(
        state.history.map((item) => item.nzoId),
        List.generate(400, (index) => 'job-${index + 1}'),
      );
      expect(state.history.any((item) => item.nzoId == 'job-200'), isTrue);
      expect(state.history.map((item) => item.nzoId).toSet(), hasLength(400));
      expect(state.hasMoreHistory, isFalse);
      await state.loadMoreHistory();
      expect(api.historyRequests, hasLength(2));
    },
  );

  testWidgets(
    'history insertion keeps unseen boundary rows reachable and refresh retains the loaded prefix',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(apiClient: api);
      addTearDown(state.dispose);
      final original = List.generate(401, (index) => _history('job-$index'));

      final initial = state.refreshHistory();
      api.historyRequests.last.complete(
        _historyPage(original.take(200).toList(), total: original.length),
      );
      await tester.pump();
      await initial;

      final inserted = [_history('newest'), ...original];
      final more = state.loadMoreHistory();
      await tester.pump();
      expect(api.historyRequests.last.start, 0);
      expect(api.historyRequests.last.limit, 400);
      api.historyRequests.last.complete(
        _historyPage(inserted.take(400).toList(), total: 402, limit: 400),
      );
      await tester.pump();
      await more;
      expect(
        state.history.map((item) => item.nzoId),
        inserted.take(400).map((item) => item.nzoId),
      );
      expect(state.history.map((item) => item.nzoId).toSet(), hasLength(400));
      expect(state.hasMoreHistory, isTrue);

      final reentry = state.refreshHistory();
      expect(api.historyRequests.last.start, 0);
      expect(api.historyRequests.last.limit, 400);
      api.historyRequests.last.complete(
        _historyPage(inserted.take(400).toList(), total: 402, limit: 400),
      );
      await tester.pump();
      await reentry;
      expect(
        state.history.map((item) => item.nzoId),
        inserted.take(400).map((item) => item.nzoId),
      );
      expect(state.history.last.nzoId, 'job-398');
      expect(state.hasMoreHistory, isTrue);

      final last = state.loadMoreHistory();
      await tester.pump();
      expect(api.historyRequests.last.start, 0);
      expect(api.historyRequests.last.limit, 600);
      api.historyRequests.last.complete(
        _historyPage(inserted, total: 402, limit: 600),
      );
      await tester.pump();
      await last;
      expect(state.history.last.nzoId, 'job-400');
      expect(state.history, hasLength(402));
      expect(state.hasMoreHistory, isFalse);

      for (final force in [false, true]) {
        final refresh = state.refreshHistory(force: force);
        expect(api.historyRequests.last.start, 0);
        expect(api.historyRequests.last.limit, 600);
        final current = inserted
            .where((item) => item.nzoId != 'job-0')
            .toList();
        api.historyRequests.last.complete(
          _historyPage(
            [...current, current.last],
            total: current.length,
            limit: 600,
          ),
        );
        await tester.pump();
        await refresh;
        expect(
          state.history.map((item) => item.nzoId),
          current.map((item) => item.nzoId),
        );
        expect(state.hasMoreHistory, isFalse);
      }
    },
  );

  for (final history in [false, true]) {
    testWidgets(
      'forced refresh coalesces only requests started after its call, history=$history',
      (tester) async {
        final api = _ControlledAPI();
        final state = SABnzbdState(apiClient: api);
        addTearDown(state.dispose);
        Future<void> refresh({bool force = false}) => history
            ? state.refreshHistory(force: force)
            : state.refreshQueue(force: force);
        void complete(String id) {
          if (history) {
            api.historyRequests.last.complete(_historyPage([_history(id)]));
          } else {
            api.queueRequests.last.complete(_queueSnapshot([_queue(id)]));
          }
        }

        if (!history) {
          state.acquireQueue();
          await tester.pump();
        }
        final original = refresh();
        final firstMutation = refresh(force: true);
        final secondMutation = refresh(force: true);
        complete('before-mutations');
        await tester.pump();
        await original;
        expect(
          history ? api.historyRequests.length : api.queueRequests.length,
          2,
        );

        var thirdFinished = false;
        final thirdMutation = refresh(
          force: true,
        ).then((_) => thirdFinished = true);
        complete('after-first-two');
        await tester.pump();
        await Future.wait([firstMutation, secondMutation]);
        expect(thirdFinished, isFalse);
        expect(
          history
              ? state.history.map((item) => item.nzoId)
              : state.queue.map((item) => item.nzoId),
          ['after-first-two'],
        );
        expect(
          history ? api.historyRequests.length : api.queueRequests.length,
          3,
        );
        complete('after-all-three');
        await tester.pump();
        await thirdMutation;
        expect(
          history
              ? state.history.map((item) => item.nzoId)
              : state.queue.map((item) => item.nzoId),
          ['after-all-three'],
        );
        await tester.pump(const Duration(seconds: 2));
        if (history) {
          expect(api.historyRequests, hasLength(3));
        } else {
          expect(api.queueRequests, hasLength(4));
          state.releaseQueue();
          complete('final-poll');
          await tester.pump();
          await tester.pump(const Duration(seconds: 4));
          expect(api.queueRequests, hasLength(4));
        }
      },
    );

    testWidgets(
      'forced refresh recovers after a timed-out read without accepting its late result, history=$history',
      (tester) async {
        final api = _ControlledAPI();
        final state = SABnzbdState(
          apiClient: api,
          requestTimeout: const Duration(seconds: 3),
        );
        addTearDown(state.dispose);
        final original = history
            ? state.refreshHistory()
            : state.refreshQueue();
        final forced = history
            ? state.refreshHistory(force: true)
            : state.refreshQueue(force: true);
        await tester.pump(const Duration(seconds: 3));
        await original;
        expect(
          history ? api.historyRequests.length : api.queueRequests.length,
          2,
        );
        expect(
          history ? state.historyError : state.queueError,
          isA<TimeoutException>(),
        );
        if (history) {
          api.historyRequests.last.complete(_historyPage([_history('fresh')]));
        } else {
          api.queueRequests.last.complete(_queueSnapshot([_queue('fresh')]));
        }
        await tester.pump();
        await forced;
        if (history) {
          api.historyRequests.first.complete(
            _historyPage([_history('obsolete')]),
          );
        } else {
          api.queueRequests.first.complete(
            _queueSnapshot([_queue('obsolete')]),
          );
        }
        await tester.pump();
        expect(
          history
              ? state.history.map((item) => item.nzoId)
              : state.queue.map((item) => item.nzoId),
          ['fresh'],
        );
        expect(history ? state.historyError : state.queueError, isNull);
      },
    );

    for (final dispose in [false, true]) {
      testWidgets(
        'pending forced refresh cannot restart after reset or dispose, history=$history dispose=$dispose',
        (tester) async {
          final api = _ControlledAPI();
          final state = SABnzbdState(apiClient: api);
          addTearDown(() {
            if (!state.isDisposed) state.dispose();
          });
          final original = history
              ? state.refreshHistory()
              : state.refreshQueue();
          final forced = history
              ? state.refreshHistory(force: true)
              : state.refreshQueue(force: true);
          if (dispose) {
            state.dispose();
          } else {
            state.reset();
          }
          if (history) {
            api.historyRequests.single.complete(
              _historyPage([_history('old')]),
            );
          } else {
            api.queueRequests.single.complete(_queueSnapshot([_queue('old')]));
          }
          await tester.pump();
          await Future.wait([original, forced]);
          expect(state.queue, isEmpty);
          expect(state.history, isEmpty);
          expect(
            history ? api.historyRequests.length : api.queueRequests.length,
            1,
          );
        },
      );
    }
  }

  testWidgets(
    'failed refresh retains last-good data and recovery clears stale errors',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(apiClient: api);
      addTearDown(state.dispose);

      final initial = Future.wait([
        state.refreshQueue(),
        state.refreshHistory(),
      ]);
      await tester.pump();
      api.queueRequests.last.complete(
        _queueSnapshot([_queue('last-good')], total: 123, speed: 12.5),
      );
      api.historyRequests.last.complete(
        _historyPage([_history('last-finished')], total: 234),
      );
      await tester.pump();
      await initial;
      final queueUpdatedAt = state.queueUpdatedAt;
      final historyUpdatedAt = state.historyUpdatedAt;
      final queueFailure = StateError('queue unavailable');
      final historyFailure = StateError('history unavailable');

      final failed = Future.wait([
        state.refreshQueue(),
        state.refreshHistory(),
      ]);
      await tester.pump();
      api.queueRequests.last.fail(queueFailure);
      api.historyRequests.last.fail(historyFailure);
      await tester.pump();
      await failed;

      expect(state.queue.map((item) => item.nzoId), ['last-good']);
      expect(state.status!.speed, 12.5);
      expect(state.queueTotal, 123);
      expect(state.queueUpdatedAt, queueUpdatedAt);
      expect(state.queueError, same(queueFailure));
      expect(state.queueStale, isTrue);
      expect(state.queueLoading, isFalse);
      expect(state.history.map((item) => item.nzoId), ['last-finished']);
      expect(state.historyTotal, 234);
      expect(state.historyUpdatedAt, historyUpdatedAt);
      expect(state.historyError, same(historyFailure));
      expect(state.historyStale, isTrue);
      expect(state.historyLoading, isFalse);

      final recovered = Future.wait([
        state.refreshQueue(),
        state.refreshHistory(),
      ]);
      await tester.pump();
      api.queueRequests.last.complete(
        _queueSnapshot([_queue('recovered')], speed: 25.75),
      );
      api.historyRequests.last.complete(_historyPage([]));
      await tester.pump();
      await recovered;

      expect(state.queue.map((item) => item.nzoId), ['recovered']);
      expect(state.status!.speed, 25.75);
      expect(state.queueTotal, 1);
      expect(state.queueError, isNull);
      expect(state.queueStale, isFalse);
      expect(state.history, isEmpty);
      expect(state.historyTotal, 0);
      expect(state.historyError, isNull);
      expect(state.historyStale, isFalse);
      expect(state.hasMoreHistory, isFalse);
    },
  );

  testWidgets(
    'two consumers share polling which survives failure and stops on release',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(
        apiClient: api,
        pollInterval: const Duration(seconds: 2),
      );
      addTearDown(state.dispose);
      var notifications = 0;
      state.addListener(() => notifications++);

      state.acquireQueue();
      state.acquireQueue();
      expect(notifications, 0);
      await tester.pump();
      expect(api.queueRequests, hasLength(1));
      await tester.pump(const Duration(seconds: 3));
      expect(api.queueRequests, hasLength(1));

      api.queueRequests.last.fail(StateError('temporary failure'));
      await tester.pump();
      expect(state.queueError, isNotNull);
      expect(state.queueLoading, isFalse);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(api.queueRequests, hasLength(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(api.queueRequests, hasLength(2));

      state.releaseQueue();
      api.queueRequests.last.complete(_queueSnapshot([_queue('recovered')]));
      await tester.pump();
      expect(state.queueError, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(api.queueRequests, hasLength(3));

      state.releaseQueue();
      api.queueRequests.last.complete(_queueSnapshot([_queue('last')]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(api.queueRequests, hasLength(3));
      expect(api.historyRequests, isEmpty);
    },
  );

  testWidgets(
    'timeout unblocks polling and late timed-out results cannot overwrite recovery',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(
        apiClient: api,
        pollInterval: const Duration(seconds: 2),
        requestTimeout: const Duration(seconds: 3),
      );
      addTearDown(state.dispose);

      state.acquireQueue();
      await tester.pump();
      final timedOut = api.queueRequests.single;
      await tester.pump(const Duration(seconds: 3));
      expect(state.queueLoading, isFalse);
      expect(state.queueError, isA<TimeoutException>());
      await tester.pump(const Duration(seconds: 2));
      expect(api.queueRequests, hasLength(2));
      api.queueRequests.last.complete(
        _queueSnapshot([_queue('fresh')], speed: 99.5),
      );
      await tester.pump();
      final updatedAt = state.queueUpdatedAt;

      timedOut.complete(_queueSnapshot([_queue('obsolete')], speed: 1));
      await tester.pump();
      expect(state.queue.map((item) => item.nzoId), ['fresh']);
      expect(state.status!.speed, 99.5);
      expect(state.queueUpdatedAt, updatedAt);
      expect(state.queueError, isNull);
      expect(state.queueStale, isFalse);
      state.releaseQueue();
    },
  );

  testWidgets(
    'reset preserves active consumers and restarts polling until both release',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(
        apiClient: api,
        pollInterval: const Duration(seconds: 2),
      );
      addTearDown(state.dispose);

      state.acquireQueue();
      state.acquireQueue();
      await tester.pump();
      expect(api.queueRequests, hasLength(1));
      api.queueRequests.single.complete(
        _queueSnapshot([_queue('before-reset')], speed: 12.5),
      );
      await tester.pump();
      expect(state.queue.map((item) => item.nzoId), ['before-reset']);
      await tester.pump(const Duration(seconds: 1));

      state.reset();
      expect(state.status, isNull);
      expect(state.queue, isEmpty);
      expect(state.queueUpdatedAt, isNull);
      expect(state.queueLoading, isFalse);
      expect(api.queueRequests, hasLength(1));
      await tester.pump();
      expect(api.queueRequests, hasLength(2));
      expect(state.queueLoading, isTrue);
      api.queueRequests.last.complete(
        _queueSnapshot([_queue('after-reset')], speed: 25),
      );
      await tester.pump();
      expect(state.queue.map((item) => item.nzoId), ['after-reset']);
      expect(state.status!.speed, 25);
      expect(state.queueUpdatedAt, isNotNull);
      expect(state.queueLoading, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(api.queueRequests, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      expect(api.queueRequests, hasLength(3));
      state.releaseQueue();
      api.queueRequests.last.complete(_queueSnapshot([_queue('one-consumer')]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(api.queueRequests, hasLength(4));
      expect(state.queue.map((item) => item.nzoId), ['one-consumer']);

      state.releaseQueue();
      api.queueRequests.last.complete(_queueSnapshot([_queue('last')]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(api.queueRequests, hasLength(4));
      expect(api.historyRequests, isEmpty);
    },
  );

  testWidgets(
    'reset clears snapshots and old requests cannot publish into the new generation',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(apiClient: api);
      addTearDown(state.dispose);
      final initial = Future.wait([
        state.refreshQueue(),
        state.refreshHistory(),
      ]);
      await tester.pump();
      api.queueRequests.last.complete(_queueSnapshot([_queue('before-reset')]));
      api.historyRequests.last.complete(
        _historyPage([_history('before-reset')]),
      );
      await tester.pump();
      await initial;

      final old = Future.wait([state.refreshQueue(), state.refreshHistory()]);
      await tester.pump();
      final oldQueue = api.queueRequests.last;
      final oldHistory = api.historyRequests.last;
      state.reset();
      expect(state.status, isNull);
      expect(state.queue, isEmpty);
      expect(state.history, isEmpty);
      expect(state.queueTotal, 0);
      expect(state.historyTotal, 0);
      expect(state.queueUpdatedAt, isNull);
      expect(state.historyUpdatedAt, isNull);
      await tester.pump();
      expect(api.queueRequests, hasLength(2));
      expect(api.historyRequests, hasLength(2));
      expect(state.queueLoading, isFalse);
      expect(state.historyLoading, isFalse);

      final current = Future.wait([
        state.refreshQueue(),
        state.refreshHistory(),
      ]);
      await tester.pump();
      expect(api.queueRequests, hasLength(3));
      expect(api.historyRequests, hasLength(3));
      api.queueRequests.last.complete(_queueSnapshot([_queue('current')]));
      api.historyRequests.last.complete(_historyPage([_history('current')]));
      await tester.pump();
      await current;
      final queueUpdatedAt = state.queueUpdatedAt;
      final historyUpdatedAt = state.historyUpdatedAt;

      oldQueue.complete(_queueSnapshot([_queue('obsolete')]));
      oldHistory.fail(StateError('obsolete failure'));
      await tester.pump();
      await old;
      expect(state.queue.map((item) => item.nzoId), ['current']);
      expect(state.history.map((item) => item.nzoId), ['current']);
      expect(state.queueUpdatedAt, queueUpdatedAt);
      expect(state.historyUpdatedAt, historyUpdatedAt);
      expect(state.queueError, isNull);
      expect(state.historyError, isNull);
      expect(state.queueLoading, isFalse);
      expect(state.historyLoading, isFalse);
    },
  );

  testWidgets(
    'dispose stops polling and ignores outstanding queue and history work',
    (tester) async {
      final api = _ControlledAPI();
      final state = SABnzbdState(apiClient: api);
      var notifications = 0;
      state.addListener(() => notifications++);
      state.acquireQueue();
      final history = state.refreshHistory();
      await tester.pump();
      expect(api.queueRequests, hasLength(1));
      expect(api.historyRequests, hasLength(1));

      state.dispose();
      expect(state.isDisposed, isTrue);
      final notificationsAtDispose = notifications;
      api.queueRequests.single.complete(_queueSnapshot([_queue('too-late')]));
      api.historyRequests.single.complete(_historyPage([_history('too-late')]));
      await tester.pump();
      await history;
      await tester.pump(const Duration(seconds: 30));

      expect(state.status, isNull);
      expect(state.queue, isEmpty);
      expect(state.history, isEmpty);
      expect(notifications, notificationsAtDispose);
      expect(api.queueRequests, hasLength(1));
      expect(api.historyRequests, hasLength(1));
    },
  );
}

class _ControlledAPI implements SABnzbdAPI {
  final queueRequests = <_Request<SABnzbdQueueSnapshot>>[];
  final historyRequests = <_Request<SABnzbdHistoryPage>>[];

  @override
  Future<SABnzbdQueueSnapshot> getQueue({int start = 0, int limit = 100}) {
    final request = _Request<SABnzbdQueueSnapshot>(start, limit);
    queueRequests.add(request);
    return request.completer.future;
  }

  @override
  Future<SABnzbdHistoryPage> getHistoryPage({int start = 0, int limit = 200}) {
    final request = _Request<SABnzbdHistoryPage>(start, limit);
    historyRequests.add(request);
    return request.completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request<T> {
  final int start;
  final int limit;
  final completer = Completer<T>();

  _Request(this.start, this.limit);

  void complete(T value) => completer.complete(value);
  void fail(Object error) => completer.completeError(error);
}

SABnzbdQueueSnapshot _queueSnapshot(
  List<SABnzbdQueueData> items, {
  int? total,
  int limit = 100,
  double speed = 0,
  double sizeLeft = 0,
}) => SABnzbdQueueSnapshot(
  status: SABnzbdStatusData(
    paused: false,
    speed: speed,
    sizeLeft: sizeLeft,
    timeLeft: '0:05:00',
    speedlimit: 75,
  ),
  items: items,
  total: total ?? items.length,
  start: 0,
  limit: limit,
);

SABnzbdHistoryPage _historyPage(
  List<SABnzbdHistoryData> items, {
  int? total,
  int limit = 200,
}) => SABnzbdHistoryPage(
  items: items,
  total: total ?? items.length,
  start: 0,
  limit: limit,
);

SABnzbdQueueData _queue(String id) => SABnzbdQueueData(
  name: id,
  nzoId: id,
  sizeTotal: 100,
  sizeLeft: 50,
  status: 'Downloading',
  timeLeft: '0:05:00',
  category: '*',
);

SABnzbdHistoryData _history(String id) => SABnzbdHistoryData(
  nzoId: id,
  name: id,
  size: 1024,
  status: 'Completed',
  failureMessage: '',
  timestamp: 1700000000,
  actionLine: '',
  category: '*',
  downloadTime: 60,
  stageLog: [],
  storageLocation: '/downloads/$id',
);
