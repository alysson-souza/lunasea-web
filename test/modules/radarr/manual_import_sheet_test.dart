import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/modules/radarr.dart';
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

  testWidgets('manual import sheet reads movies from the selected instance', (
    tester,
  ) async {
    await LunaBackendState.hydrate({
      'preferences': {'activeProfile': 'default', 'drawerManualOrder': []},
      'profiles': [
        {'id': 'default'},
      ],
    });
    final requests = <RequestOptions>[];
    final selectedState = _RadarrState('selected-radarr', requests);
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => SettingsStore())],
        child: MaterialApp(
          navigatorKey: LunaRouter.navigator,
          home: ChangeNotifierProvider<RadarrState>.value(
            value: selectedState,
            child: ChangeNotifierProvider<RadarrManualImportDetailsTileState>(
              create: (context) =>
                  RadarrManualImportDetailsTileState(context, _manualImport()),
              child: Builder(
                builder: (context) {
                  return Scaffold(
                    body: TextButton(
                      onPressed: () => RadarrBottomModalSheets()
                          .configureManualImport(context),
                      child: const Text('Open sheet'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('radarr.SelectMovie'));
    await tester.pumpAndSettle();

    expect(requests.where((r) => r.method == 'GET').map((r) => r.uri.host), [
      'selected-radarr.test',
    ]);
    // Let the sheet's animations finish so no ticker leaks into teardown.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox.shrink());
    selectedState.dispose();
  });
}

RadarrManualImport _manualImport() =>
    RadarrManualImport(id: 1, relativePath: 'movies/some.movie.mkv');

class _RadarrState extends RadarrState {
  late final RadarrAPI client;
  _RadarrState(String host, List<RequestOptions> requests) {
    client = RadarrAPI(host: 'https://$host.test', apiKey: '');
    client.httpClient.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: <dynamic>[],
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
  RadarrAPI get api => client;
  @override
  Future<List<RadarrMovie>>? get movies => client.movie.getAll();
}
