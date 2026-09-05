import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/cache/memory/memory_store.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await LunaMemoryStore().initialize();
  });

  tearDown(LunaBackendState.clear);

  testWidgets(
    'episode sheet deletes the file on the selected Sonarr instance',
    (tester) async {
      final (finder, requests, selectedState, season) = await _pumpHarness(
        tester,
      );
      await tester.tap(find.text('Open episode'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('lunasea.Delete').last);
      await tester.pumpAndSettle();

      expect(
        requests
            .where((r) => r.method == 'DELETE')
            .map((r) => r.uri.toString()),
        ['https://selected-anime.test/api/v3/episodefile/856'],
      );
      expect((await season().episodes)![156]!.hasFile, isFalse);
      await _teardown(tester, selectedState);
    },
  );

  testWidgets('episode sheet searches on the selected Sonarr instance', (
    tester,
  ) async {
    final (_, requests, selectedState, _) = await _pumpHarness(tester);
    await tester.tap(find.text('Open episode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sonarr.Automatic'));
    await tester.pumpAndSettle();

    expect(
      requests.where((r) => r.method == 'POST').map((r) => r.uri.toString()),
      ['https://selected-anime.test/api/v3/command'],
    );
    await _teardown(tester, selectedState);
  });

  testWidgets('episode sheet removes queue records on the selected instance', (
    tester,
  ) async {
    final (_, requests, selectedState, _) = await _pumpHarness(
      tester,
      queueRecords: [_queueRecord()],
    );
    await tester.tap(find.text('Open episode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('queued episode').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('lunasea.Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lunasea.Remove').last);
    await tester.pumpAndSettle();

    expect(
      requests.where((r) => r.method == 'DELETE').map((r) => r.uri.toString()),
      ['https://selected-anime.test/api/v3/queue/42'],
    );
    await _teardown(tester, selectedState);
  });
}

Future<void> _teardown(WidgetTester tester, _SonarrState selectedState) async {
  // Let the result snackbar dismiss so its animation ticker does not leak
  // into widget tree finalization.
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox.shrink());
  selectedState.dispose();
}

Future<(Finder, List<RequestOptions>, _SonarrState, _SeasonState Function())>
_pumpHarness(
  WidgetTester tester, {
  List<SonarrQueueRecord> queueRecords = const [],
}) async {
  await LunaBackendState.hydrate({
    'preferences': {'activeProfile': 'default', 'drawerManualOrder': []},
    'profiles': [
      {'id': 'default'},
    ],
  });
  final requests = <RequestOptions>[];
  final selectedState = _SonarrState('selected-anime', requests);
  late _SeasonState season;
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SettingsStore())],
      child: MaterialApp(
        navigatorKey: LunaRouter.navigator,
        home: ChangeNotifierProvider<SonarrState>.value(
          value: selectedState,
          child: Builder(
            builder: (context) {
              return ChangeNotifierProvider<SonarrSeasonDetailsState>(
                create: (_) =>
                    season = _SeasonState(context, queuedRecords: queueRecords),
                child: Builder(
                  builder: (context) {
                    return Scaffold(
                      body: TextButton(
                        onPressed: () => SonarrEpisodeDetailsSheet(
                          context: context,
                          episode: _episode(),
                          episodeFile: _file(),
                          queueRecords: queueRecords,
                        ).show(),
                        child: const Text('Open episode'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  return (find.text('lunasea.Delete'), requests, selectedState, () => season);
}

SonarrEpisode _episode() => SonarrEpisode(
  id: 156,
  seriesId: 4,
  seasonNumber: 1,
  episodeNumber: 56,
  title: "Georgine's Visit",
  hasFile: true,
  monitored: true,
  episodeFileId: 856,
  airDateUtc: DateTime.utc(2026, 9, 4),
);
SonarrEpisodeFile _file() => SonarrEpisodeFile(
  id: 856,
  relativePath: 'series/episode56.mkv',
  size: 1000,
  qualityCutoffNotMet: false,
);
SonarrQueueRecord _queueRecord() => SonarrQueueRecord(
  id: 42,
  episodeId: 156,
  title: 'queued episode',
  status: SonarrQueueStatus.DOWNLOADING,
  protocol: SonarrProtocol.USENET,
  size: 1000,
  sizeleft: 500,
  timeleft: '00:01:00',
  downloadClient: 'sab',
);

class _SonarrState extends SonarrState {
  late final SonarrAPI client;
  _SonarrState(String host, List<RequestOptions> requests) {
    client = SonarrAPI(host: 'https://$host.test', apiKey: '');
    client.httpClient.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: <String, dynamic>{},
            ),
          );
        },
      ),
    );
  }
  @override
  void reset() {}
  @override
  bool get enabled => true;
  @override
  SonarrAPI get api => client;
}

class _SeasonState extends SonarrSeasonDetailsState {
  final data = <int, SonarrEpisode>{156: _episode()};
  final List<SonarrQueueRecord> queuedRecords;
  _SeasonState(BuildContext context, {this.queuedRecords = const []})
    : super(context: context, seriesId: 4, seasonNumber: 1);
  @override
  Future<Map<int, SonarrEpisode>> get episodes => Future.value(data);
  @override
  Future<Map<int, SonarrEpisodeFile>> get files => Future.value({856: _file()});
  @override
  Future<List<SonarrQueueRecord>> get queue => Future.value(queuedRecords);
  @override
  Future<SonarrHistoryPage?> getEpisodeHistory(int episodeId) async =>
      SonarrHistoryPage()..records = [];
  @override
  Future<void> fetchState(
    BuildContext context, {
    bool shouldFetchEpisodes = true,
    bool shouldFetchFiles = true,
    bool shouldFetchHistory = true,
    bool shouldFetchQueue = true,
    bool queueHardCheck = true,
    bool shouldFetchMostRecentEpisodeHistory = true,
  }) async {}
  @override
  Future<void> fetchHistory(BuildContext context) async {}
  @override
  Future<void> fetchEpisodeHistory(
    BuildContext context,
    int? episodeId,
  ) async {}
  @override
  Future<void> setSingleEpisode(SonarrEpisode episode) async {
    data[episode.id!] = episode;
    notifyListeners();
  }
}
