import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/snapshot.dart';
import 'package:lunasea/modules/sabnzbd/core/history_location.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/routes/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/widgets/history_tile.dart';
import 'package:lunasea/modules/sabnzbd/widgets/navigation_bar.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/system/preferences/preference.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/widgets/pages/instance_not_configured.dart';
import 'package:lunasea/widgets/ui/drawer/drawer.dart';
import 'package:lunasea/widgets/ui/theme.dart';
import 'package:provider/provider.dart';

const _pollInterval = Duration(seconds: 2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> translations;
  late bool previousReflectImperativeAPIs;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await EasyLocalization.ensureInitialized();
    translations =
        jsonDecode(await rootBundle.loadString('assets/localization/en.json'))
            as Map<String, dynamic>;
    previousReflectImperativeAPIs = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
  });

  tearDownAll(() {
    GoRouter.optionURLReflectsImperativeAPIs = previousReflectImperativeAPIs;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
  });

  setUp(() {
    LunaBackendState.clear();
    debugClearCurrentInstanceIdsForTesting();
  });
  tearDown(() {
    LunaBackendState.clear();
    debugClearCurrentInstanceIdsForTesting();
  });

  for (final count in [0, 1, 2]) {
    testWidgets('aggregate root displays $count configured sources', (
      tester,
    ) async {
      final instances = [
        if (count >= 1) _instance('primary'),
        if (count >= 2) _instance('secondary', sortOrder: 1),
      ];
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: instances,
      );

      expect(harness.uri.toString(), '/sabnzbd?tab=queue');
      expect(find.byType(InstanceNotConfiguredPage), findsNothing);
      expect(harness.sources.length, count);
      expect(
        find.byType(SABnzbdNavigationBar),
        count == 0 ? findsNothing : findsOneWidget,
      );
      for (final instance in instances) {
        expect(find.text('${instance.host} queue'), findsOneWidget);
        expect(harness.source(instance).api.queueCalls, 1);
      }
    });
  }

  testWidgets('direct instance path and same-page tab queries stay usable', (
    tester,
  ) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
      initialLocation: '/sabnzbd/primary?tab=queue',
    );
    final source = harness.source(instance);
    expect(find.text('primary'), findsOneWidget);
    expect(find.text('${instance.host} queue'), findsOneWidget);
    expect(source.api.historyCalls, 0);

    harness.router.go('/sabnzbd/primary?tab=history');
    await tester.pumpAndSettle();
    expect(harness.uri.toString(), '/sabnzbd/primary?tab=history');
    expect(_historyTile(instance), findsOneWidget);
    expect(source.api.historyCalls, 1);

    harness.router.go('/sabnzbd/primary?tab=queue');
    await tester.pumpAndSettle();
    expect(find.text('${instance.host} queue'), findsOneWidget);
    expect(_historyTile(instance), findsNothing);
    expect(source.api.historyCalls, 1);
  });

  testWidgets('aggregate tab query updates the already mounted shell', (
    tester,
  ) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
    );
    harness.router.go('/sabnzbd?tab=history');
    await tester.pumpAndSettle();
    expect(find.text('Search loaded history'), findsOneWidget);
    expect(_historyTile(instance), findsOneWidget);

    harness.router.go('/sabnzbd?tab=queue');
    await tester.pumpAndSettle();
    expect(find.text('${instance.host} queue'), findsOneWidget);
    expect(find.text('Search loaded history').hitTestable(), findsNothing);
  });

  for (final count in [1, 2]) {
    for (final tab in ['queue', 'history']) {
      testWidgets(
        'title selector roundtrips $count sources on $tab at narrow width',
        (tester) async {
          final primary = _instance('primary');
          final secondary = _instance('secondary', sortOrder: 1);
          final harness = await _RouteHarness.mount(
            tester,
            translations: translations,
            instances: [primary, if (count == 2) secondary],
            initialLocation: '/sabnzbd?tab=$tab',
          );
          await tester.binding.setSurfaceSize(const Size(390, 844));
          await tester.pumpAndSettle();

          await _openInstanceSelector(tester);
          _expectSelectedInstance('All Instances');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(harness.uri.toString(), '/sabnzbd?tab=$tab');

          await _selectInstance(tester, 'primary');
          expect(harness.uri.toString(), '/sabnzbd/primary?tab=$tab');
          await _openInstanceSelector(tester);
          _expectSelectedInstance('primary');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(harness.uri.toString(), '/sabnzbd/primary?tab=$tab');

          if (count == 2) {
            await _selectInstance(tester, 'secondary');
            expect(harness.uri.toString(), '/sabnzbd/secondary?tab=$tab');
            await _openInstanceSelector(tester);
            _expectSelectedInstance('secondary');
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
          }

          await _selectInstance(tester, 'All Instances');
          expect(harness.uri.toString(), '/sabnzbd?tab=$tab');
          if (tab == 'history') {
            expect(_historyTile(primary), findsOneWidget);
            if (count == 2) expect(_historyTile(secondary), findsOneWidget);
          } else {
            expect(find.text('${primary.host} queue'), findsOneWidget);
            if (count == 2) {
              expect(find.text('${secondary.host} queue'), findsOneWidget);
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final tab in ['queue', 'history']) {
    testWidgets(
      'choosing the active source adds no route or entry load on $tab',
      (tester) async {
        final harness = await _RouteHarness.mount(
          tester,
          translations: translations,
          instances: [
            _instance('primary'),
            _instance('secondary', sortOrder: 1),
          ],
          initialLocation: '/sabnzbd?tab=$tab',
        );

        Future<void> chooseCurrent(String name, String path) async {
          final beforeCancel = [
            for (final source in harness.sources) source.api.queueCalls,
          ];
          final historyBeforeCancel = [
            for (final source in harness.sources) source.api.historyCalls,
          ];
          await _openInstanceSelector(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          final afterCancel = [
            for (final source in harness.sources) source.api.queueCalls,
          ];
          final historyAfterCancel = [
            for (final source in harness.sources) source.api.historyCalls,
          ];
          await _selectInstance(tester, name);
          expect(harness.uri.toString(), '$path?tab=$tab');
          for (var index = 0; index < harness.sources.length; index++) {
            expect(
              harness.sources[index].api.queueCalls - afterCancel[index],
              afterCancel[index] - beforeCancel[index],
              reason:
                  'Choosing the active source must not add an entry fetch '
                  'beyond normal menu dismissal.',
            );
            expect(
              harness.sources[index].api.historyCalls -
                  historyAfterCancel[index],
              historyAfterCancel[index] - historyBeforeCancel[index],
              reason:
                  'Choosing the active source must not add a history fetch '
                  'beyond normal menu dismissal.',
            );
          }
        }

        await chooseCurrent('All Instances', '/sabnzbd');
        expect(harness.router.canPop(), isFalse);
        await _selectInstance(tester, 'primary');
        await chooseCurrent('primary', '/sabnzbd/primary');
        harness.router.pop();
        await tester.pumpAndSettle();
        expect(harness.uri.toString(), '/sabnzbd?tab=$tab');
        expect(harness.router.canPop(), isFalse);
      },
    );

    testWidgets('selector back restores each source on $tab', (tester) async {
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [_instance('primary'), _instance('secondary', sortOrder: 1)],
        initialLocation: '/sabnzbd?tab=$tab',
      );
      await _selectInstance(tester, 'primary');
      await _selectInstance(tester, 'secondary');
      await _selectInstance(tester, 'All Instances');

      for (final path in [
        '/sabnzbd/secondary',
        '/sabnzbd/primary',
        '/sabnzbd',
      ]) {
        harness.router.pop();
        await tester.pumpAndSettle();
        expect(harness.uri.toString(), '$path?tab=$tab');
        await _openInstanceSelector(tester);
        _expectSelectedInstance(
          path == '/sabnzbd' ? 'All Instances' : path.split('/').last,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('selector browser back and forward restore $tab', (
      tester,
    ) async {
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [_instance('primary'), _instance('secondary', sortOrder: 1)],
        initialLocation: '/sabnzbd?tab=$tab',
      );
      RouteInformation browserLocation() {
        final location = harness.router.routeInformationParser
            .restoreRouteInformation(
              harness.router.routerDelegate.currentConfiguration,
            )!;
        return RouteInformation(
          uri: location.uri,
          state: jsonDecode(jsonEncode(location.state)),
        );
      }

      final locations = [browserLocation()];
      for (final name in ['primary', 'secondary', 'All Instances']) {
        await _selectInstance(tester, name);
        locations.add(browserLocation());
      }
      for (final index in [2, 1, 0, 1, 2, 3]) {
        expect(
          await harness.router.routeInformationProvider.didPushRouteInformation(
            locations[index],
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(harness.uri, locations[index].uri);
        await _openInstanceSelector(tester);
        _expectSelectedInstance(switch (index) {
          1 => 'primary',
          2 => 'secondary',
          _ => 'All Instances',
        });
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets(
    'instance title selector preserves a newly selected History tab',
    (tester) async {
      final primary = _instance('primary');
      final secondary = _instance('secondary', sortOrder: 1);
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [primary, secondary],
        initialLocation: '/sabnzbd/secondary?tab=queue',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SABnzbdNavigationBar),
          matching: find.byWidgetPredicate(
            (widget) => widget is GButton && widget.text == 'History',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.uri.toString(), '/sabnzbd/secondary?tab=history');

      await _selectInstance(tester, 'All Instances');
      expect(harness.uri.toString(), '/sabnzbd?tab=history');
      expect(_historyTile(primary), findsOneWidget);
      expect(_historyTile(secondary), findsOneWidget);
    },
  );

  testWidgets('owned History stages return to the aggregate History URL', (
    tester,
  ) async {
    final primary = _instance('primary');
    final secondary = _instance('secondary', sortOrder: 1);
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [primary, secondary],
      initialLocation: '/sabnzbd?tab=history',
    );
    await tester.tap(_historyTile(secondary));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stages').hitTestable());
    await tester.pumpAndSettle();

    expect(harness.uri.path, '/sabnzbd/secondary/history/stages');
    expect(harness.uri.queryParameters['nzoId'], 'shared-job');
    expect(harness.uri.queryParameters['profile'], secondary.profileId);
    expect(harness.uri.toString(), isNot(contains(secondary.apiKey)));
    expect(harness.uri.toString(), isNot(contains(secondary.host)));
    expect(harness.source(secondary).api.historyItemCalls, 0);
    expect(find.text('${secondary.host} verification'), findsOneWidget);
    expect(find.text('${primary.host} verification'), findsNothing);
    final calls = harness.sources
        .map((source) => source.api.queueCalls)
        .toList();
    await tester.pump(const Duration(seconds: 6));
    expect(harness.sources.map((source) => source.api.queueCalls), calls);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
    await tester.pumpAndSettle();
    expect(harness.uri.toString(), '/sabnzbd?tab=history');
    expect(find.text('Search loaded history'), findsOneWidget);
    expect(_historyTile(secondary), findsOneWidget);
  });

  testWidgets('owned server statistics return to aggregate History', (
    tester,
  ) async {
    final primary = _instance('primary');
    final secondary = _instance('secondary', sortOrder: 1);
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [primary, secondary],
      initialLocation: '/sabnzbd?tab=history',
    );
    await tester.tap(find.byTooltip('Choose server actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('secondary').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Status & Statistics'));
    await tester.pumpAndSettle();

    expect(harness.uri.path, '/sabnzbd/secondary/statistics');
    expect(harness.source(primary).api.statisticsCalls, 0);
    expect(harness.source(secondary).api.statisticsCalls, 1);
    expect(find.text('${secondary.host} version'), findsOneWidget);
    final calls = harness.sources
        .map((source) => source.api.queueCalls)
        .toList();
    await tester.pump(const Duration(seconds: 6));
    expect(harness.sources.map((source) => source.api.queueCalls), calls);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
    await tester.pumpAndSettle();
    expect(harness.uri.toString(), '/sabnzbd?tab=history');
    expect(find.text('Search loaded history'), findsOneWidget);
  });

  testWidgets('direct statistics path uses the configured owner API', (
    tester,
  ) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
      initialLocation: '/sabnzbd/primary/statistics?tab=history',
    );
    expect(harness.uri.toString(), '/sabnzbd/primary/statistics?tab=history');
    expect(find.text('${instance.host} version'), findsOneWidget);
    expect(harness.source(instance).api.statisticsCalls, 1);
    expect(harness.source(instance).api.queueCalls, 0);
  });

  testWidgets('direct history stages without a record fail safely', (
    tester,
  ) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
      initialLocation: '/sabnzbd/primary/history/stages?tab=history',
    );
    expect(
      harness.uri.toString(),
      '/sabnzbd/primary/history/stages?tab=history',
    );
    expect(find.text('History Record Not Found'), findsOneWidget);
    expect(harness.source(instance).api.queueCalls, 0);
  });

  testWidgets('query-only History stages restore the exact owned record', (
    tester,
  ) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
      initialLocation: _historyLocation(instance),
    );
    expect(find.text('${instance.host} verification'), findsOneWidget);
    expect(harness.source(instance).api.historyItemIds, ['shared-job']);
    expect(harness.source(instance).api.historyCalls, 0);
    expect(harness.source(instance).api.queueCalls, 0);
  });

  testWidgets('mounted History stages follow query record changes', (
    tester,
  ) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
      initialLocation: _historyLocation(instance),
    );
    expect(find.text('${instance.host} verification'), findsOneWidget);

    harness.router.go(_historyLocation(instance, nzoId: 'missing-job'));
    await tester.pumpAndSettle();
    expect(find.text('History Record Not Found'), findsOneWidget);
    expect(find.text('${instance.host} verification'), findsNothing);

    harness.router.go(_historyLocation(instance));
    await tester.pumpAndSettle();
    expect(find.text('${instance.host} verification'), findsOneWidget);
    expect(harness.source(instance).api.historyItemIds, [
      'shared-job',
      'missing-job',
      'shared-job',
    ]);
    expect(tester.takeException(), isNull);
  });

  for (final mismatch in ['profile', 'configuration']) {
    testWidgets(
      'History stages reject $mismatch mismatch before reading data',
      (tester) async {
        final original = _instance('primary');
        final replacement = mismatch == 'profile'
            ? _instance('primary', profile: 'other')
            : LunaServiceInstance.fromJson({
                ...original.toJson(),
                'upstreamUrl': 'https://replacement.example/',
                'apiKey': 'replacement-key',
              });
        final harness = await _RouteHarness.mount(
          tester,
          translations: translations,
          instances: [original, if (mismatch == 'profile') replacement],
          initialLocation: '/sabnzbd?tab=history',
        );
        await tester.tap(_historyTile(original));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stages').hitTestable());
        await tester.pumpAndSettle();
        final location = harness.uri.toString();
        expect(find.text('${original.host} verification'), findsOneWidget);

        if (mismatch == 'profile') {
          harness.changeProfile('other');
        } else {
          harness.replaceInstances([replacement]);
        }
        await tester.pumpAndSettle();
        expect(find.text('History Record Not Found'), findsOneWidget);
        expect(find.text('${original.host} verification'), findsNothing);
        expect(find.text('${replacement.host} verification'), findsNothing);
        expect(harness.source(replacement).api.historyItemCalls, 0);

        harness.router.go('/sabnzbd/primary?tab=queue');
        await tester.pumpAndSettle();
        harness.router.go(location);
        await tester.pumpAndSettle();
        expect(find.text('History Record Not Found'), findsOneWidget);
        expect(harness.source(replacement).api.historyItemCalls, 0);
      },
    );
  }

  testWidgets('query-only missing History record is not a request error', (
    tester,
  ) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
      initialLocation: _historyLocation(instance, nzoId: 'missing-job'),
    );
    expect(find.text('History Record Not Found'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);
    expect(harness.source(instance).api.historyItemIds, ['missing-job']);
  });

  testWidgets('History request failure offers a working retry', (tester) async {
    final instance = _instance('primary');
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [instance],
      initialLocation: _historyLocation(instance),
      configureApi: (api) =>
          api.historyItemError = StateError('Request failed'),
    );
    expect(find.text('History Record Not Found'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);
    harness.source(instance).api.historyItemError = null;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('${instance.host} verification'), findsOneWidget);
    expect(harness.source(instance).api.historyItemCalls, 2);
  });

  for (final stages in <List<dynamic>>[
    [],
    [
      {'name': 'Empty verification', 'actions': <String>[]},
    ],
  ]) {
    testWidgets('History stages safely render absent logs $stages', (
      tester,
    ) async {
      final instance = _instance('primary');
      await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [instance],
        initialLocation: _historyLocation(instance),
        configureApi: (api) => api.stageLog = stages,
      );
      expect(find.text('No Stage Logs Found'), findsOneWidget);
      expect(find.text('Empty verification'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'History previews actual logs safely after its source is replaced',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final instance = _instance('primary');
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [instance],
        initialLocation: _historyLocation(instance),
        configureApi: (api) => api.stageLog = [
          {'name': 'Empty verification', 'actions': <String>[]},
          {
            'name': 'Extraction',
            'actions': ['Actual extraction<br/>Finished'],
          },
        ],
      );
      expect(find.text('No Stage Logs Found'), findsNothing);
      expect(find.text('Empty verification'), findsNothing);
      expect(find.text('Extraction'), findsOneWidget);
      expect(
        find.text('Actual extraction.\nFinished', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Extraction'));
      await tester.pumpAndSettle();
      expect(
        find.text('Actual extraction.\nFinished', findRichText: true),
        findsWidgets,
      );
      harness.replaceInstances([
        LunaServiceInstance.fromJson({
          ...instance.toJson(),
          'upstreamUrl': 'https://replacement.example/',
        }),
      ]);
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Copy'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('History Record Not Found'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _expireNotification(tester);
    },
  );

  for (final invalidate in [false, true]) {
    testWidgets(
      'History failure captures source and job, invalidated=$invalidate',
      (tester) async {
        final original = _instance('primary');
        final replacement = _instance('primary', profile: 'other');
        final harness = await _RouteHarness.mount(
          tester,
          translations: translations,
          instances: [original, replacement],
          initialLocation: '/sabnzbd?tab=history',
          configureApi: (api) => api.historyStatus = 'Failed',
        );
        await tester.longPress(_historyTile(original));
        await tester.pumpAndSettle();
        if (invalidate) {
          harness.changeProfile('other');
          await tester.pump();
        }
        await tester.tap(find.text('Retry Job'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Failed to Update History (primary: ${original.host} history)',
          ),
          findsOneWidget,
        );
        expect(harness.source(original).api.retryCalls, invalidate ? 0 : 1);
        if (invalidate) expect(harness.source(replacement).api.retryCalls, 0);
        await _expireNotification(tester);
      },
    );
  }

  for (final initialLocation in [
    '/sabnzbd?tab=queue',
    '/sabnzbd/primary?tab=queue',
  ]) {
    testWidgets(
      'same ID across profiles replaces the visible owner at $initialLocation',
      (tester) async {
        final original = _instance('primary');
        final replacement = _instance('primary', profile: 'other');
        final harness = await _RouteHarness.mount(
          tester,
          translations: translations,
          instances: [original, replacement],
          initialLocation: initialLocation,
        );
        final oldSource = harness.source(original);
        harness.changeProfile('other');
        await tester.pumpAndSettle();
        final newSource = harness.source(replacement);
        expect(find.text('${original.host} queue'), findsNothing);
        expect(find.text('${replacement.host} queue'), findsOneWidget);
        expect(newSource.state, isNot(same(oldSource.state)));
        final stoppedCalls = oldSource.api.queueCalls;
        final activeCalls = newSource.api.queueCalls;
        await tester.pump(_pollInterval);
        expect(oldSource.api.queueCalls, stoppedCalls);
        expect(newSource.api.queueCalls, activeCalls + 1);
        expect(harness.uri.toString(), initialLocation);
      },
    );

    testWidgets(
      'configuration replacement releases old demand at $initialLocation',
      (tester) async {
        final original = _instance('primary');
        final replacement = LunaServiceInstance.fromJson({
          ...original.toJson(),
          'upstreamUrl': 'https://replacement.example/',
          'apiKey': 'replacement-key',
        });
        final harness = await _RouteHarness.mount(
          tester,
          translations: translations,
          instances: [original],
          initialLocation: initialLocation,
        );
        final oldSource = harness.source(original);
        harness.replaceInstances([replacement]);
        await tester.pumpAndSettle();
        final newSource = harness.source(replacement);
        expect(oldSource.state.isDisposed, isTrue);
        expect(find.text('${original.host} queue'), findsNothing);
        expect(find.text('${replacement.host} queue'), findsOneWidget);
        final stoppedCalls = oldSource.api.queueCalls;
        final activeCalls = newSource.api.queueCalls;
        await tester.pump(_pollInterval);
        expect(oldSource.api.queueCalls, stoppedCalls);
        expect(newSource.api.queueCalls, activeCalls + 1);
      },
    );
  }

  testWidgets('membership changes replace groups and release removed demand', (
    tester,
  ) async {
    final primary = _instance('primary');
    final secondary = _instance('secondary', sortOrder: 1);
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [primary],
    );
    final removed = harness.source(primary);
    harness.replaceInstances([secondary]);
    await tester.pumpAndSettle();
    expect(find.text('${primary.host} queue'), findsNothing);
    expect(find.text('${secondary.host} queue'), findsOneWidget);
    final active = harness.source(secondary);
    final stoppedCalls = removed.api.queueCalls;
    final activeCalls = active.api.queueCalls;
    await tester.pump(_pollInterval);
    expect(removed.api.queueCalls, stoppedCalls);
    expect(active.api.queueCalls, activeCalls + 1);

    harness.replaceInstances([]);
    await tester.pumpAndSettle();
    expect(find.byType(SABnzbdNavigationBar), findsNothing);
    final lastCalls = active.api.queueCalls;
    await tester.pump(const Duration(seconds: 6));
    expect(active.api.queueCalls, lastCalls);
  });

  for (final path in [
    '/sabnzbd/primary?tab=history',
    '/sabnzbd/primary/statistics',
    '/sabnzbd/primary/history/stages',
  ]) {
    testWidgets('disabled instance is safe at $path', (tester) async {
      final instance = _instance('primary', enabled: false);
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [instance],
        initialLocation: path,
      );
      expect(find.byType(InstanceNotConfiguredPage), findsOneWidget);
      expect(find.textContaining('"primary" is disabled.'), findsOneWidget);
      expect(harness.sources, isEmpty);
      await tester.pump(const Duration(seconds: 6));
      expect(harness.sources, isEmpty);
    });
  }

  testWidgets(
    'disabling the visible individual stops polling and hides its data',
    (tester) async {
      final instance = _instance('primary');
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [instance],
        initialLocation: '/sabnzbd/primary?tab=history',
      );
      final source = harness.source(instance);
      harness.replaceInstances([
        LunaServiceInstance.fromJson({...instance.toJson(), 'enabled': false}),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(InstanceNotConfiguredPage), findsOneWidget);
      expect(_historyTile(instance), findsNothing);
      final stoppedCalls = source.api.queueCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(source.api.queueCalls, stoppedCalls);
    },
  );

  testWidgets('an empty aggregate starts showing newly enabled membership', (
    tester,
  ) async {
    final harness = await _RouteHarness.mount(
      tester,
      translations: translations,
      instances: [],
    );
    final instance = _instance('primary');
    harness.replaceInstances([instance]);
    await tester.pumpAndSettle();
    expect(harness.uri.toString(), '/sabnzbd?tab=queue');
    expect(find.text('${instance.host} queue'), findsOneWidget);
    expect(harness.source(instance).api.queueCalls, 1);
  });

  for (final path in ['/sabnzbd?tab=history', '/sabnzbd/primary/statistics']) {
    testWidgets('profile replacement refreshes visible owned data at $path', (
      tester,
    ) async {
      final original = _instance('primary');
      final replacement = _instance('primary', profile: 'other');
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [original, replacement],
        initialLocation: path,
      );
      final isStatistics = path.endsWith('statistics');
      final originalData = isStatistics
          ? find.text('${original.host} version')
          : _historyTile(original);
      final replacementData = isStatistics
          ? find.text('${replacement.host} version')
          : _historyTile(replacement);
      expect(originalData, findsOneWidget);
      final oldSource = harness.source(original);
      harness.changeProfile('other');
      await tester.pumpAndSettle();
      expect(harness.uri.toString(), path);
      expect(originalData, findsNothing);
      expect(replacementData, findsOneWidget);
      final stoppedQueueCalls = oldSource.api.queueCalls;
      final stoppedHistoryCalls = oldSource.api.historyCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(oldSource.api.queueCalls, stoppedQueueCalls);
      expect(oldSource.api.historyCalls, stoppedHistoryCalls);
    });
  }

  for (final change in ['profile', 'configuration']) {
    testWidgets('$change change invalidates a previously opened owned record', (
      tester,
    ) async {
      final original = _instance('primary');
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [
          original,
          _instance('primary', profile: 'other'),
        ],
        initialLocation: '/sabnzbd?tab=history',
      );
      await tester.tap(_historyTile(original));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stages').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('${original.host} verification'), findsOneWidget);

      if (change == 'profile') {
        harness.changeProfile('other');
      } else {
        harness.replaceInstances([
          LunaServiceInstance.fromJson({
            ...original.toJson(),
            'upstreamUrl': 'https://replacement.example/',
          }),
        ]);
      }
      await tester.pumpAndSettle();
      expect(harness.uri.path, '/sabnzbd/primary/history/stages');
      expect(find.text('${original.host} verification'), findsNothing);
      expect(find.text('History Record Not Found'), findsOneWidget);
    });
  }

  testWidgets(
    'SAB drawer groups root and instances and navigates both entries',
    (tester) async {
      final primary = _instance('primary');
      final secondary = _instance('secondary', sortOrder: 1);
      final harness = await _RouteHarness.mount(
        tester,
        translations: translations,
        instances: [primary, secondary],
      );
      await tester.tap(find.byIcon(Icons.menu_rounded).hitTestable());
      await tester.pumpAndSettle();
      final drawer = find.byType(LunaDrawer);
      expect(
        find.descendant(of: drawer, matching: find.text('SABnzbd')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: drawer, matching: find.text('primary')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: drawer, matching: find.text('secondary')),
        findsOneWidget,
      );
      expect(find.text('SABnzbd - primary'), findsNothing);
      expect(find.text('SABnzbd - secondary'), findsNothing);
      await tester.tap(
        find.descendant(of: drawer, matching: find.text('secondary')),
      );
      await tester.pumpAndSettle();
      expect(harness.uri.path, '/sabnzbd/secondary');
      expect(find.text('${secondary.host} queue'), findsOneWidget);
      expect(find.text('${primary.host} queue'), findsNothing);

      await tester.tap(
        find
            .descendant(
              of: find.byType(SABnzbdRoute).last,
              matching: find.byIcon(Icons.menu_rounded),
            )
            .hitTestable()
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(LunaDrawer),
          matching: find.text('SABnzbd'),
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.uri.path, '/sabnzbd');
      expect(find.text('${primary.host} queue'), findsOneWidget);
      expect(find.text('${secondary.host} queue'), findsOneWidget);
    },
  );
}

Future<void> _expireNotification(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _openInstanceSelector(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Switch Instance').hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _selectInstance(WidgetTester tester, String name) async {
  await _openInstanceSelector(tester);
  await tester.tap(
    find.ancestor(
      of: find.text(name).last,
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectSelectedInstance(String name) {
  expect(
    find.ancestor(
      of: find.text(name).last,
      matching: find.byWidgetPredicate(
        (widget) => widget is CheckedPopupMenuItem && widget.checked,
      ),
    ),
    findsOneWidget,
  );
}

Finder _historyTile(LunaServiceInstance instance) => find
    .byWidgetPredicate(
      (widget) =>
          widget is SABnzbdHistoryTile &&
          widget.data.name == '${instance.host} history' &&
          widget.state?.instance?.ref == instance.ref,
    )
    .hitTestable();

String _historyLocation(
  LunaServiceInstance instance, {
  String nzoId = 'shared-job',
}) => Uri(
  path: '/sabnzbd/${instance.id}/history/stages',
  queryParameters: SABnzbdHistoryLocation.forInstance(
    instance,
    nzoId,
  ).queryParameters,
).toString();

LunaServiceInstance _instance(
  String id, {
  String profile = 'default',
  int sortOrder = 0,
  bool enabled = true,
}) => LunaServiceInstance(
  id: id,
  profileId: profile,
  module: LunaModule.SABNZBD,
  displayName: id,
  enabled: enabled,
  host: 'https://$profile-$id.example/',
  apiKey: '$profile-$id-key',
  sortOrder: sortOrder,
);

class _RouteHarness {
  final profiles = ProfilesStore();
  final sources = <_Source>[];
  late final LunaModuleStateRegistry<SABnzbdState> registry;
  late final GoRouter router;

  final void Function(_RouteAPI)? configureApi;

  _RouteHarness({this.configureApi}) {
    registry = LunaModuleStateRegistry<SABnzbdState>(
      create: (instance) {
        final source = _Source(instance);
        configureApi?.call(source.api);
        sources.add(source);
        return source.state;
      },
    );
  }

  Uri get uri => router.routeInformationProvider.value.uri;

  _Source source(LunaServiceInstance instance) => sources.lastWhere(
    (source) =>
        source.instance.ref == instance.ref &&
        source.instance.host == instance.host,
  );

  static Future<_RouteHarness> mount(
    WidgetTester tester, {
    required Map<String, dynamic> translations,
    required List<LunaServiceInstance> instances,
    String initialLocation = '/sabnzbd?tab=queue',
    void Function(_RouteAPI)? configureApi,
  }) async {
    await LunaBackendState.hydrate({
      'preferences': {
        'activeProfile': 'default',
        'drawerAutomaticManage': true,
        'drawerManualOrder': [],
      },
      'profiles': [
        {'id': 'default'},
        {'id': 'other'},
      ],
      'serviceInstances': instances
          .map((instance) => instance.toJson())
          .toList(),
    });
    final harness = _RouteHarness(configureApi: configureApi);
    LunaRouter.navigator = GlobalKey<NavigatorState>();
    harness.router = GoRouter(
      navigatorKey: LunaRouter.navigator,
      initialLocation: initialLocation,
      overridePlatformDefaultLocation: true,
      routes: [SABnzbdRoutes.CONSOLIDATED.routes],
    );
    LunaRouter.router = harness.router;
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      final calls = harness.sources
          .map((source) => source.api.queueCalls)
          .toList();
      await tester.pump(const Duration(seconds: 6));
      expect(harness.sources.map((source) => source.api.queueCalls), calls);
      expect(tester.takeException(), isNull);
      harness.router.dispose();
      harness.registry.dispose();
      harness.profiles.dispose();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfilesStore>.value(value: harness.profiles),
          ChangeNotifierProvider<LunaModuleStateRegistry<SABnzbdState>>.value(
            value: harness.registry,
          ),
          ChangeNotifierProvider(create: (_) => SettingsStore()),
          ChangeNotifierProvider(create: (_) => IndexersStore()),
          ChangeNotifierProvider(create: (_) => ExternalModulesStore()),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/localization',
          startLocale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          saveLocale: false,
          assetLoader: _EnglishAssetLoader(translations),
          child: Builder(
            builder: (context) => MaterialApp.router(
              theme: LunaTheme().activeTheme(),
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: harness.router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  void changeProfile(String profile) {
    BackendPreferenceGroup.hydrate(() {
      LunaSeaPreferences.ENABLED_PROFILE.update(profile);
    });
    profiles.refresh();
  }

  void replaceInstances(List<LunaServiceInstance> instances) {
    profiles.active.serviceInstances
      ..clear()
      ..addAll(instances);
    profiles.refresh();
  }
}

class _EnglishAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _EnglishAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations;
}

class _Source {
  final LunaServiceInstance instance;
  late final api = _RouteAPI(instance.host);
  late final state = SABnzbdState(
    instance: instance,
    apiClient: api,
    pollInterval: _pollInterval,
  );

  _Source(this.instance);
}

class _RouteAPI implements SABnzbdAPI {
  final String label;
  int queueCalls = 0;
  int historyCalls = 0;
  int statisticsCalls = 0;
  final historyItemIds = <String>[];
  int get historyItemCalls => historyItemIds.length;
  Object? historyItemError;
  List<dynamic>? stageLog;
  String historyStatus = 'Completed';
  int retryCalls = 0;

  _RouteAPI(this.label);

  @override
  Future<SABnzbdHistoryData?> getHistoryItem(String nzoId) async {
    historyItemIds.add(nzoId);
    final error = historyItemError;
    if (error != null) throw error;
    return nzoId == 'shared-job' ? _history : null;
  }

  @override
  Future<bool> retryFailedJob(String nzoId) async {
    retryCalls++;
    return false;
  }

  SABnzbdHistoryData get _history => SABnzbdHistoryData(
    nzoId: 'shared-job',
    name: '$label history',
    size: 1024,
    status: historyStatus,
    failureMessage: '',
    timestamp: 100,
    actionLine: '',
    category: '*',
    downloadTime: 1,
    stageLog:
        stageLog ??
        [
          {
            'name': '$label verification',
            'actions': ['Verified stored samples'],
          },
        ],
    storageLocation: '/downloads/shared',
  );

  @override
  Future<SABnzbdQueueSnapshot> getQueue({
    int start = 0,
    int limit = 100,
  }) async {
    queueCalls++;
    return SABnzbdQueueSnapshot(
      status: SABnzbdStatusData(
        paused: false,
        speed: 1,
        sizeLeft: 2,
        timeLeft: '0:00:02',
        speedlimit: 0,
      ),
      items: [
        SABnzbdQueueData(
          name: '$label queue',
          nzoId: 'shared-job',
          sizeTotal: 4,
          sizeLeft: 2,
          status: 'Downloading',
          timeLeft: '0:00:02',
          category: '*',
        ),
      ],
      total: 1,
      start: start,
      limit: limit,
    );
  }

  @override
  Future<SABnzbdHistoryPage> getHistoryPage({
    int start = 0,
    int limit = 200,
  }) async {
    historyCalls++;
    return SABnzbdHistoryPage(
      items: [_history],
      total: 1,
      start: start,
      limit: limit,
    );
  }

  @override
  Future<SABnzbdStatisticsData> getStatistics() async {
    statisticsCalls++;
    return SABnzbdStatisticsData(
      servers: [],
      uptime: '1 day',
      version: '$label version',
      speedlimit: 0,
      speedlimitPercentage: 0,
      tempFreespace: 10,
      finalFreespace: 20,
      dailyUsage: 1,
      weeklyUsage: 2,
      monthlyUsage: 3,
      totalUsage: 4,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
