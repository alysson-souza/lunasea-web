import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/router/routes/sonarr.dart';

void main() {
  tearDown(debugClearCurrentInstanceIdsForTesting);

  testWidgets('returns pushed route instance from go_router state', (
    tester,
  ) async {
    final router = _router(initialLocation: '/sonarr');
    await _pumpRouter(tester, router);

    router.push('/sonarr/nas-tv/series/1');
    await tester.pumpAndSettle();

    expect(currentInstanceId(LunaModule.SONARR), 'nas-tv');
  });

  testWidgets('consolidated root clears stale cached instance', (tester) async {
    final router = _router(initialLocation: '/sonarr');
    await _pumpRouter(tester, router);
    debugRememberCurrentInstanceIdForTesting(LunaModule.SONARR, 'old-tv');

    expect(currentInstanceId(LunaModule.SONARR), isNull);
  });

  testWidgets('direct instance route resolves instance from URL state', (
    tester,
  ) async {
    final router = _router(initialLocation: '/sonarr/nas-tv/series/1');
    await _pumpRouter(tester, router);

    expect(currentInstanceId(LunaModule.SONARR), 'nas-tv');
  });

  testWidgets('consolidated route navigation does not inherit instance', (
    tester,
  ) async {
    final router = _router(initialLocation: '/sonarr/nas-tv/series/1');
    await _pumpRouter(tester, router);

    SonarrRoutes.CONSOLIDATED.go(buildTree: true);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/sonarr');
    expect(currentInstanceId(LunaModule.SONARR), isNull);
  });

  testWidgets('instance navigation writes detail route to browser URL', (
    tester,
  ) async {
    final router = _router(initialLocation: '/sonarr');
    await _pumpRouter(tester, router);

    SonarrRoutes.SERIES.goInstance(
      instanceId: 'nas-tv',
      params: {'series': '1'},
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/sonarr/nas-tv/series/1',
    );
  });
}

GoRouter _router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/sonarr',
        name: 'sonarr:CONSOLIDATED',
        builder: (_, _) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: ':instanceId',
            name: 'sonarr:HOME',
            builder: (_, _) => const SizedBox.shrink(),
            routes: [
              GoRoute(
                path: 'series/:series',
                name: 'sonarr:SERIES',
                builder: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpRouter(WidgetTester tester, GoRouter router) async {
  LunaRouter.router = router;
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}
