import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/action_target.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/snapshot.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/system/preferences/preference.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(LunaBackendState.clear);
  tearDown(LunaBackendState.clear);

  group('SABnzbdActionTarget', () {
    testWidgets(
      'supplied owner wins over another provided server with the same job ID',
      (tester) async {
        final fixture = await _ActionFixture.mount(tester);
        await fixture.firstState.refreshQueue();
        await fixture.ownerState.refreshQueue();
        final target = SABnzbdActionTarget.capture(
          fixture.context,
          state: fixture.ownerState,
        );

        expect(target.instance.ref, fixture.owner.ref);
        expect(target.state, same(fixture.ownerState));
        expect(() => target.validate(fixture.context), returnsNormally);
        await target.run(
          fixture.context,
          (api) => api.pauseSingleJob('shared-job'),
        );

        expect(fixture.ownerApi.pausedJobs, {'shared-job'});
        expect(fixture.firstApi.pausedJobs, isEmpty);
        expect(fixture.ownerState.queue.single.status, 'Paused');
        expect(fixture.firstState.queue.single.status, 'Downloading');
        expect(fixture.ownerApi.queueRequests, 2);
        expect(fixture.firstApi.queueRequests, 1);
        expect(fixture.ownerApi.historyRequests, 0);
        expect(fixture.firstApi.historyRequests, 0);
      },
    );

    testWidgets('capture without an explicit state keeps its provided owner', (
      tester,
    ) async {
      final fixture = await _ActionFixture.mount(tester);
      final target = SABnzbdActionTarget.capture(fixture.context);

      await target.run(
        fixture.context,
        (api) => api.pauseSingleJob('shared-job'),
      );

      expect(target.instance.ref, fixture.first.ref);
      expect(target.state, same(fixture.firstState));
      expect(fixture.firstApi.pausedJobs, {'shared-job'});
      expect(fixture.ownerApi.pausedJobs, isEmpty);
      expect(fixture.firstState.queue.single.status, 'Paused');
      expect(fixture.ownerApi.queueRequests, 0);
    });

    testWidgets('history-changing success refreshes only the captured owner', (
      tester,
    ) async {
      final fixture = await _ActionFixture.mount(tester);
      await fixture.firstState.refreshHistory();
      await fixture.ownerState.refreshHistory();
      expect(fixture.ownerState.history.single.nzoId, 'shared-job');
      final target = SABnzbdActionTarget.capture(
        fixture.context,
        state: fixture.ownerState,
      );

      await target.run(
        fixture.context,
        (api) => api.deleteHistory('shared-job'),
        refreshHistory: true,
      );

      expect(fixture.ownerApi.deletedHistory, ['shared-job']);
      expect(fixture.firstApi.deletedHistory, isEmpty);
      expect(fixture.ownerApi.queueRequests, 1);
      expect(fixture.ownerApi.historyRequests, 2);
      expect(fixture.ownerState.queue.single.nzoId, 'shared-job');
      expect(fixture.ownerState.history, isEmpty);
      expect(fixture.firstState.history.single.nzoId, 'shared-job');
      expect(fixture.firstApi.queueRequests, 0);
      expect(fixture.firstApi.historyRequests, 1);
    });

    for (final history in [false, true]) {
      testWidgets(
        'mutation waits for post-action snapshots when reads are in flight, history=$history',
        (tester) async {
          final fixture = await _ActionFixture.mount(tester);
          await fixture.firstState.refreshQueue();
          await fixture.firstState.refreshHistory();
          fixture.ownerApi.holdReads = true;
          final beforeQueue = fixture.ownerState.refreshQueue();
          final beforeHistory = history
              ? fixture.ownerState.refreshHistory()
              : Future<void>.value();
          final target = SABnzbdActionTarget.capture(
            fixture.context,
            state: fixture.ownerState,
          );
          var finished = false;
          final action = target
              .run(
                fixture.context,
                history
                    ? (api) => api.deleteHistory('shared-job')
                    : (api) => api.pauseSingleJob('shared-job'),
                refreshHistory: history,
              )
              .then((_) => finished = true);
          await tester.pump();
          expect(finished, isFalse);
          expect(fixture.ownerApi.queueRequests, 1);
          expect(fixture.ownerApi.historyRequests, history ? 1 : 0);

          fixture.ownerApi.queueReleases.first.complete();
          if (history) fixture.ownerApi.historyReleases.first.complete();
          await tester.pump();
          await Future.wait([beforeQueue, beforeHistory]);
          expect(finished, isFalse);
          expect(fixture.ownerApi.queueRequests, 2);
          expect(fixture.ownerApi.historyRequests, history ? 2 : 0);

          fixture.ownerApi.queueReleases.last.complete();
          if (history) fixture.ownerApi.historyReleases.last.complete();
          await tester.pump();
          await action;
          expect(finished, isTrue);
          if (history) {
            expect(fixture.ownerState.history, isEmpty);
          } else {
            expect(fixture.ownerState.queue.single.status, 'Paused');
          }
          expect(fixture.firstState.queue.single.status, 'Downloading');
          expect(fixture.firstState.history.single.nzoId, 'shared-job');
          expect(fixture.firstApi.queueRequests, 1);
          expect(fixture.firstApi.historyRequests, 1);
        },
      );
    }

    for (final change in <String>[
      'active profile',
      'removed instance',
      'disabled instance',
      'empty host',
      'host',
      'api key',
      'headers',
      'username',
      'password',
      'connection mode',
      'in-place headers',
      'disposed state',
      'unmounted context',
    ]) {
      testWidgets(
        '$change after capture rejects submission without side effects',
        (tester) async {
          final fixture = await _ActionFixture.mount(tester);
          final target = SABnzbdActionTarget.capture(
            fixture.context,
            state: fixture.ownerState,
          );
          final capturedContext = fixture.context;

          switch (change) {
            case 'active profile':
              BackendPreferenceGroup.hydrate(() {
                LunaSeaPreferences.ENABLED_PROFILE.update('other');
              });
              fixture.profiles.refresh();
              break;
            case 'removed instance':
              fixture.profiles.active.serviceInstances.removeWhere(
                (instance) => instance.ref == fixture.owner.ref,
              );
              fixture.profiles.refresh();
              break;
            case 'disabled instance':
              fixture.replaceOwner({'enabled': false});
              break;
            case 'empty host':
              fixture.replaceOwner({'upstreamUrl': ''});
              break;
            case 'host':
              fixture.replaceOwner({
                'upstreamUrl': 'https://replacement.example/',
              });
              break;
            case 'api key':
              fixture.replaceOwner({'apiKey': 'replacement-key'});
              break;
            case 'headers':
              fixture.replaceOwner({
                'headers': {'X-Owner': 'replacement'},
              });
              break;
            case 'username':
              fixture.replaceOwner({'username': 'replacement-user'});
              break;
            case 'password':
              fixture.replaceOwner({'password': 'replacement-password'});
              break;
            case 'connection mode':
              fixture.replaceOwner({'connectionMode': 'gateway'});
              break;
            case 'in-place headers':
              fixture.owner.headers['X-Owner'] = 'changed-after-capture';
              fixture.profiles.refresh();
              break;
            case 'disposed state':
              fixture.ownerState.dispose();
              break;
            case 'unmounted context':
              await tester.pumpWidget(const SizedBox.shrink());
              break;
          }

          var submissions = 0;
          await expectLater(
            target.run(capturedContext, (api) {
              submissions++;
              return api.pauseSingleJob('shared-job');
            }, refreshHistory: true),
            throwsA(isA<StateError>()),
          );

          expect(submissions, 0);
          expect(fixture.ownerApi.pausedJobs, isEmpty);
          expect(fixture.firstApi.pausedJobs, isEmpty);
          expect(fixture.ownerApi.queueRequests, 0);
          expect(fixture.ownerApi.historyRequests, 0);
          expect(fixture.firstApi.queueRequests, 0);
          expect(fixture.firstApi.historyRequests, 0);
        },
      );
    }

    for (final refreshHistory in [false, true]) {
      testWidgets(
        'API false rejects success without refreshing, history=$refreshHistory',
        (tester) async {
          final fixture = await _ActionFixture.mount(tester);
          fixture.ownerApi.mutationResult = false;
          final target = SABnzbdActionTarget.capture(
            fixture.context,
            state: fixture.ownerState,
          );

          await expectLater(
            target.run(
              fixture.context,
              (api) => api.pauseSingleJob('shared-job'),
              refreshHistory: refreshHistory,
            ),
            throwsA(isA<StateError>()),
          );

          expect(fixture.ownerApi.pauseAttempts, ['shared-job']);
          expect(fixture.ownerApi.pausedJobs, isEmpty);
          expect(fixture.firstApi.pauseAttempts, isEmpty);
          expect(fixture.ownerApi.queueRequests, 0);
          expect(fixture.ownerApi.historyRequests, 0);
          expect(fixture.firstApi.queueRequests, 0);
          expect(fixture.firstApi.historyRequests, 0);
        },
      );
    }
  });
}

class _ActionFixture {
  final ProfilesStore profiles;
  final LunaServiceInstance first;
  final LunaServiceInstance owner;
  final _ActionAPI firstApi;
  final _ActionAPI ownerApi;
  final SABnzbdState firstState;
  final SABnzbdState ownerState;
  late BuildContext context;

  _ActionFixture({
    required this.profiles,
    required this.first,
    required this.owner,
    required this.firstApi,
    required this.ownerApi,
    required this.firstState,
    required this.ownerState,
  });

  static Future<_ActionFixture> mount(WidgetTester tester) async {
    BackendPreferenceGroup.hydrate(() {
      LunaSeaPreferences.ENABLED_PROFILE.update('default');
    });
    LunaBackendState.profiles['default'] = LunaProfile(
      key: 'default',
      serviceInstances: [
        _instance('first', sortOrder: 0),
        _instance('owner', sortOrder: 1),
      ],
    );
    LunaBackendState.profiles['other'] = LunaProfile(
      key: 'other',
      serviceInstances: [_instance('owner', profileId: 'other')],
    );
    final profiles = ProfilesStore();
    final instances = profiles.enabledInstances('default', LunaModule.SABNZBD);
    final firstApi = _ActionAPI();
    final ownerApi = _ActionAPI();
    final fixture = _ActionFixture(
      profiles: profiles,
      first: instances[0],
      owner: instances[1],
      firstApi: firstApi,
      ownerApi: ownerApi,
      firstState: SABnzbdState(instance: instances[0], apiClient: firstApi),
      ownerState: SABnzbdState(instance: instances[1], apiClient: ownerApi),
    );
    addTearDown(() {
      if (!fixture.firstState.isDisposed) fixture.firstState.dispose();
      if (!fixture.ownerState.isDisposed) fixture.ownerState.dispose();
      profiles.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfilesStore>.value(value: profiles),
          ChangeNotifierProvider<SABnzbdState>.value(value: fixture.firstState),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              fixture.context = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return fixture;
  }

  void replaceOwner(Map<String, dynamic> changes) {
    final instances = profiles.active.serviceInstances;
    final index = instances.indexWhere((instance) => instance.ref == owner.ref);
    instances[index] = LunaServiceInstance.fromJson({
      ...owner.toJson(),
      ...changes,
    });
    profiles.refresh();
  }
}

LunaServiceInstance _instance(
  String id, {
  String profileId = 'default',
  int sortOrder = 0,
}) => LunaServiceInstance(
  id: id,
  profileId: profileId,
  module: LunaModule.SABNZBD,
  enabled: true,
  sortOrder: sortOrder,
  host: 'https://$id.example/',
  apiKey: '$id-key',
  headers: {'X-Owner': id},
);

class _ActionAPI implements SABnzbdAPI {
  bool mutationResult = true;
  final List<String> pauseAttempts = [];
  final Set<String> pausedJobs = {};
  final List<String> deletedHistory = [];
  int queueRequests = 0;
  int historyRequests = 0;
  bool holdReads = false;
  final queueReleases = <Completer<void>>[];
  final historyReleases = <Completer<void>>[];

  @override
  Future<bool> pauseSingleJob(String nzoId) async {
    pauseAttempts.add(nzoId);
    if (mutationResult) pausedJobs.add(nzoId);
    return mutationResult;
  }

  @override
  Future<bool> deleteHistory(String nzoId) async {
    if (mutationResult) deletedHistory.add(nzoId);
    return mutationResult;
  }

  @override
  Future<SABnzbdQueueSnapshot> getQueue({
    int start = 0,
    int limit = 100,
  }) async {
    queueRequests++;
    final snapshot = SABnzbdQueueSnapshot(
      status: SABnzbdStatusData(
        paused: false,
        speed: 1,
        sizeLeft: 2,
        timeLeft: '0:00:02',
        speedlimit: 0,
      ),
      items: [
        SABnzbdQueueData(
          name: 'Shared title',
          nzoId: 'shared-job',
          sizeTotal: 4,
          sizeLeft: 2,
          status: pausedJobs.contains('shared-job') ? 'Paused' : 'Downloading',
          timeLeft: '0:00:02',
          category: '*',
        ),
      ],
      total: 1,
      start: start,
      limit: limit,
    );
    if (holdReads) {
      final release = Completer<void>();
      queueReleases.add(release);
      await release.future;
    }
    return snapshot;
  }

  @override
  Future<SABnzbdHistoryPage> getHistoryPage({
    int start = 0,
    int limit = 200,
  }) async {
    historyRequests++;
    final items = deletedHistory.contains('shared-job')
        ? <SABnzbdHistoryData>[]
        : [
            SABnzbdHistoryData(
              nzoId: 'shared-job',
              name: 'Shared title',
              size: 1024,
              status: 'Completed',
              failureMessage: '',
              timestamp: 100,
              actionLine: '',
              category: '*',
              downloadTime: 1,
              stageLog: [],
              storageLocation: '/downloads/shared',
            ),
          ];
    final snapshot = SABnzbdHistoryPage(
      items: items,
      total: items.length,
      start: start,
      limit: limit,
    );
    if (holdReads) {
      final release = Completer<void>();
      historyReleases.add(release);
      await release.future;
    }
    return snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
