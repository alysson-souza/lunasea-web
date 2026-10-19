import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/snapshot.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/widgets/queue_tile.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/system/preferences/preference.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/widgets/ui/block/block.dart';
import 'package:lunasea/widgets/ui/theme.dart';
import 'package:provider/provider.dart';

const _pollInterval = Duration(minutes: 1);

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

  testWidgets(
    'cancelling the aggregate server picker leaves both owners intact',
    (tester) async {
      final harness = await _PickerHarness.mount(tester, translations);
      final first = harness.sources['primary']!;
      final second = harness.sources['secondary']!;

      await tester.tap(find.byTooltip('Choose server actions').hitTestable());
      await tester.pumpAndSettle();
      expect(_serverRow('Primary Server'), findsOneWidget);
      expect(_serverRow('Archive Server'), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(_serverRow('Primary Server'), findsNothing);
      expect(_serverRow('Archive Server'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byTooltip('Choose server actions').hitTestable(),
        findsOneWidget,
      );
      expect(
        harness.router.routeInformationProvider.value.uri.toString(),
        '/sabnzbd?tab=queue',
      );
      _expectDownloadingSource(first);
      _expectDownloadingSource(second);
      for (final source in harness.sources.values) {
        expect(source.api.actions, isEmpty);
        expect(source.api.unexpectedCalls, isEmpty);
        expect(source.api.paused, isFalse);
      }
    },
  );

  testWidgets('choosing the second server pauses only its duplicate-ID queue', (
    tester,
  ) async {
    final harness = await _PickerHarness.mount(tester, translations);
    final first = harness.sources['primary']!;
    final second = harness.sources['secondary']!;
    expect(first.instance.ref, isNot(second.instance.ref));
    expect(first.state.queue.single.nzoId, 'shared-job');
    expect(second.state.queue.single.nzoId, 'shared-job');
    expect(first.state.queue.single.name, second.state.queue.single.name);

    await tester.tap(find.byTooltip('Choose server actions').hitTestable());
    await tester.pumpAndSettle();
    expect(_serverRow('Primary Server'), findsOneWidget);
    await tester.tap(_serverRow('Archive Server'));
    await tester.pumpAndSettle();

    final menu = find.byType(AlertDialog);
    expect(menu, findsOneWidget);
    expect(
      find.descendant(of: menu, matching: find.text('Archive Server')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menu, matching: find.text('Primary Server')),
      findsNothing,
    );
    final pause = find
        .descendant(
          of: menu,
          matching: find.widgetWithText(ListTile, 'Pause Queue'),
        )
        .hitTestable();
    expect(pause, findsOneWidget);
    await tester.tap(pause);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(first.api.actions, isEmpty);
    expect(second.api.actions, ['pause']);
    expect(first.api.unexpectedCalls, isEmpty);
    expect(second.api.unexpectedCalls, isEmpty);
    expect(first.api.paused, isFalse);
    expect(second.api.paused, isTrue);
    _expectDownloadingSource(first);
    expect(second.state.paused, isTrue);
    expect(second.state.status!.paused, isTrue);
    expect(second.state.status!.speed, 0);
    expect(second.state.queue, hasLength(1));
    expect(second.state.queue.single.name, 'Shared download');
    expect(second.state.queue.single.status, 'Paused');
    expect(second.state.queue.single.nzoId, 'shared-job');
    expect(first.state.queueError, isNull);
    expect(second.state.queueError, isNull);
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/sabnzbd?tab=queue',
    );
  });

  testWidgets('a rejected duplicate job action identifies its captured owner', (
    tester,
  ) async {
    final harness = await _PickerHarness.mount(tester, translations);
    final first = harness.sources['primary']!;
    final second = harness.sources['secondary']!;
    second.api.pauseJobResult = false;
    final jobs = find.byType(SABnzbdQueueTile);
    expect(jobs, findsNWidgets(2));
    expect(find.text('Shared download'), findsNWidgets(2));
    expect(
      find.descendant(
        of: jobs.at(1),
        matching: find.text('Archive Server', findRichText: true),
      ),
      findsOneWidget,
    );

    await tester.tap(jobs.at(1));
    await tester.pumpAndSettle();
    final menu = find.byType(AlertDialog);
    expect(menu, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: menu,
        matching: find.widgetWithText(ListTile, 'Pause Job'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final failure = find.textContaining('Failed to Update Job').hitTestable();
    expect(failure, findsOneWidget);
    final failureText = tester.widget<Text>(failure).data!;
    expect(failureText, contains('Archive Server'));
    expect(failureText, contains('Shared download'));
    expect(failureText, isNot(contains('Primary Server')));
    expect(find.text('Job Paused'), findsNothing);
    expect(first.api.actions, isEmpty);
    expect(second.api.actions, ['pause-job:shared-job']);
    expect(first.api.unexpectedCalls, isEmpty);
    expect(second.api.unexpectedCalls, isEmpty);
    expect(first.api.paused, isFalse);
    expect(second.api.paused, isFalse);
    _expectDownloadingSource(first);
    _expectDownloadingSource(second);
    await _expireNotification(tester);
  });

  testWidgets('cancelling a job menu sends no action to either owner', (
    tester,
  ) async {
    final harness = await _PickerHarness.mount(tester, translations);
    await tester.tap(find.byType(SABnzbdQueueTile).at(1));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Failed to Update Job'), findsNothing);
    expect(find.text('Job Paused'), findsNothing);
    for (final source in harness.sources.values) {
      expect(source.api.actions, isEmpty);
      expect(source.api.unexpectedCalls, isEmpty);
      expect(source.api.paused, isFalse);
      _expectDownloadingSource(source);
    }
  });

  testWidgets('the one-source All view labels its queue jobs', (tester) async {
    await _PickerHarness.mount(
      tester,
      translations,
      instances: [_instance('primary', 'Primary Server', 0)],
    );
    final job = find.byType(SABnzbdQueueTile);
    expect(job, findsOneWidget);
    expect(
      find
          .descendant(
            of: job,
            matching: find.text('Primary Server', findRichText: true),
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Shared download'), findsOneWidget);
  });

  testWidgets('a pending job menu retains its owner after a profile change', (
    tester,
  ) async {
    final harness = await _PickerHarness.mount(
      tester,
      translations,
      profiles: ['default', 'other'],
    );
    final sources = harness.sources.values.toList();
    await tester.tap(find.byType(SABnzbdQueueTile).at(1));
    await tester.pumpAndSettle();
    final menu = find.byType(AlertDialog);
    expect(menu, findsOneWidget);

    BackendPreferenceGroup.hydrate(() {
      LunaSeaPreferences.ENABLED_PROFILE.update('other');
    });
    harness.profiles.refresh();
    await tester.pumpAndSettle();
    expect(menu, findsOneWidget);
    await tester.tap(
      find.descendant(
        of: menu,
        matching: find.widgetWithText(ListTile, 'Pause Job'),
      ),
    );
    await tester.pumpAndSettle();

    final failure = find.textContaining('Failed to Update Job').hitTestable();
    expect(failure, findsOneWidget);
    final failureText = tester.widget<Text>(failure).data!;
    expect(failureText, contains('Archive Server'));
    expect(failureText, contains('Shared download'));
    expect(failureText, isNot(contains('Primary Server')));
    expect(find.text('Job Paused'), findsNothing);
    for (final source in sources) {
      expect(source.api.actions, isEmpty);
      expect(source.api.unexpectedCalls, isEmpty);
      expect(source.api.paused, isFalse);
    }
    await _expireNotification(tester);
    expect(tester.takeException(), isNull);
  });

  for (final invalidation in ['profile', 'removed source', 'configuration']) {
    testWidgets(
      'a pending server menu rejects $invalidation after its caller unmounts',
      (tester) async {
        final harness = await _PickerHarness.mount(
          tester,
          translations,
          profiles: ['default', 'other'],
        );
        final sources = harness.sources.values.toList();
        final caller = tester.element(
          find.byTooltip('Choose server actions').hitTestable(),
        );
        await tester.tap(find.byTooltip('Choose server actions').hitTestable());
        await tester.pumpAndSettle();
        await tester.tap(_serverRow('Archive Server'));
        await tester.pumpAndSettle();
        final menu = find.byType(AlertDialog);
        expect(menu, findsOneWidget);
        expect(
          find.descendant(of: menu, matching: find.text('Archive Server')),
          findsOneWidget,
        );

        switch (invalidation) {
          case 'profile':
            BackendPreferenceGroup.hydrate(() {
              LunaSeaPreferences.ENABLED_PROFILE.update('other');
            });
            break;
          case 'removed source':
            harness.profiles.active.serviceInstances.removeWhere(
              (instance) => instance.id == 'secondary',
            );
            break;
          case 'configuration':
            final instances = harness.profiles.active.serviceInstances;
            final index = instances.indexWhere(
              (instance) => instance.id == 'secondary',
            );
            instances[index] = LunaServiceInstance.fromJson({
              ...instances[index].toJson(),
              'upstreamUrl': 'https://replacement.example/',
            });
            break;
        }
        harness.profiles.refresh();
        await tester.pump();
        expect(caller.mounted, isFalse);
        expect(menu, findsOneWidget);
        await tester.tap(
          find.descendant(
            of: menu,
            matching: find.widgetWithText(ListTile, 'Pause Queue'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        final failure = find
            .textContaining('Server Action Failed')
            .hitTestable();
        expect(failure, findsOneWidget);
        final failureText = tester.widget<Text>(failure).data!;
        expect(failureText, contains('Archive Server'));
        expect(failureText, isNot(contains('Primary Server')));
        for (final source in {...sources, ...harness.sources.values}) {
          expect(source.api.actions, isEmpty);
          expect(source.api.unexpectedCalls, isEmpty);
          expect(source.api.paused, isFalse);
        }
        await _expireNotification(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final invalidation in ['profile', 'removed source', 'configuration']) {
    for (final action in [
      'Pause Job',
      'Change Priority',
      'Rename Job',
      'Set Password',
      'Delete Job',
    ]) {
      testWidgets(
        '$action from a pending dialog rejects $invalidation invalidation',
        (tester) async {
          final harness = await _PickerHarness.mount(
            tester,
            translations,
            profiles: ['default', 'other'],
          );
          final sources = harness.sources.values.toList();
          await tester.tap(find.byType(SABnzbdQueueTile).at(1));
          await tester.pumpAndSettle();
          if (action != 'Pause Job') {
            await tester.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(ListTile, action),
              ),
            );
            await tester.pumpAndSettle();
          }
          if (action == 'Rename Job' || action == 'Set Password') {
            await tester.enterText(find.byType(TextFormField), 'changed-value');
            await tester.pumpAndSettle();
          }

          switch (invalidation) {
            case 'profile':
              BackendPreferenceGroup.hydrate(() {
                LunaSeaPreferences.ENABLED_PROFILE.update('other');
              });
              break;
            case 'removed source':
              harness.profiles.active.serviceInstances.removeWhere(
                (instance) => instance.id == 'secondary',
              );
              break;
            case 'configuration':
              final instances = harness.profiles.active.serviceInstances;
              final index = instances.indexWhere(
                (instance) => instance.id == 'secondary',
              );
              instances[index] = LunaServiceInstance.fromJson({
                ...instances[index].toJson(),
                'upstreamUrl': 'https://replacement.example/',
              });
              expect(instances[index].host, 'https://replacement.example/');
              break;
          }
          harness.profiles.refresh();
          await tester.pump();
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          final selection = switch (action) {
            'Change Priority' => find.widgetWithText(ListTile, 'Normal'),
            'Rename Job' => find.widgetWithText(TextButton, 'Rename'),
            'Set Password' => find.widgetWithText(TextButton, 'Set'),
            'Delete Job' => find.widgetWithText(TextButton, 'Delete'),
            _ => find.widgetWithText(ListTile, 'Pause Job'),
          };
          await tester.tap(find.descendant(of: dialog, matching: selection));
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsNothing);
          final failure = find
              .textContaining('Failed to Update Job')
              .hitTestable();
          expect(failure, findsOneWidget);
          final failureText = tester.widget<Text>(failure).data!;
          expect(failureText, contains('Archive Server'));
          expect(failureText, contains('Shared download'));
          expect(failureText, isNot(contains('Primary Server')));
          expect(find.text('Job Paused'), findsNothing);
          for (final source in {...sources, ...harness.sources.values}) {
            expect(source.api.actions, isEmpty);
            expect(source.api.unexpectedCalls, isEmpty);
            expect(source.api.paused, isFalse);
          }
          expect(
            harness.router.routeInformationProvider.value.uri.toString(),
            '/sabnzbd?tab=queue',
          );
          await _expireNotification(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _expireNotification(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void _expectDownloadingSource(_Source source) {
  expect(source.state.paused, isFalse);
  final status = source.state.status!;
  expect(status.paused, isFalse);
  expect(status.speed, 1);
  expect(status.sizeLeft, 2);
  expect(status.timeLeft, '0:00:02');
  expect(status.speedlimit, 0);
  expect(source.state.queue, hasLength(1));
  final job = source.state.queue.single;
  expect(job.nzoId, 'shared-job');
  expect(job.name, 'Shared download');
  expect(job.status, 'Downloading');
  expect(job.sizeTotal, 4);
  expect(job.sizeLeft, 2);
  expect(job.timeLeft, '0:00:02');
  expect(job.category, '*');
  expect(source.state.queueError, isNull);
}

Finder _serverRow(String name) => find
    .byWidgetPredicate(
      (widget) =>
          widget is LunaBlock && widget.title == name && widget.onTap != null,
    )
    .hitTestable();

LunaServiceInstance _instance(String id, String name, int sortOrder) =>
    LunaServiceInstance(
      id: id,
      profileId: 'default',
      module: LunaModule.SABNZBD,
      displayName: name,
      enabled: true,
      host: 'https://$id.example/',
      apiKey: '$id-key',
      sortOrder: sortOrder,
    );

class _PickerHarness {
  final profiles = ProfilesStore();
  final sources = <String, _Source>{};
  late final LunaModuleStateRegistry<SABnzbdState> registry;
  late final GoRouter router;

  _PickerHarness() {
    registry = LunaModuleStateRegistry<SABnzbdState>(
      create: (instance) {
        final source = _Source(instance);
        sources[instance.id] = source;
        return source.state;
      },
    );
  }

  static Future<_PickerHarness> mount(
    WidgetTester tester,
    Map<String, dynamic> translations, {
    List<LunaServiceInstance>? instances,
    List<String> profiles = const ['default'],
  }) async {
    instances ??= [
      _instance('primary', 'Primary Server', 0),
      _instance('secondary', 'Archive Server', 1),
    ];
    await LunaBackendState.hydrate({
      'preferences': {
        'activeProfile': 'default',
        'drawerAutomaticManage': true,
        'drawerManualOrder': [],
      },
      'profiles': profiles.map((id) => {'id': id}).toList(),
      'serviceInstances': instances
          .map((instance) => instance.toJson())
          .toList(),
    });
    final harness = _PickerHarness();
    LunaRouter.navigator = GlobalKey<NavigatorState>();
    harness.router = GoRouter(
      navigatorKey: LunaRouter.navigator,
      initialLocation: '/sabnzbd?tab=queue',
      overridePlatformDefaultLocation: true,
      routes: [SABnzbdRoutes.CONSOLIDATED.routes],
    );
    LunaRouter.router = harness.router;
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() async {
      while (find.byType(AlertDialog).evaluate().isNotEmpty) {
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      final calls = harness.sources.values
          .map((source) => source.api.queueCalls)
          .toList();
      await tester.pump(_pollInterval * 2);
      expect(
        harness.sources.values.map((source) => source.api.queueCalls),
        calls,
      );
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
    for (final source in harness.sources.values) {
      expect(source.state.queueError, isNull);
      expect(source.state.queue.single.nzoId, 'shared-job');
    }
    expect(harness.sources, hasLength(instances.length));
    return harness;
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
  final api = _PickerAPI();
  late final state = SABnzbdState(
    instance: instance,
    apiClient: api,
    pollInterval: _pollInterval,
  );

  _Source(this.instance);
}

class _PickerAPI implements SABnzbdAPI {
  int queueCalls = 0;
  bool paused = false;
  bool pauseJobResult = true;
  final actions = <String>[];
  final unexpectedCalls = <Symbol>[];

  @override
  Future<SABnzbdQueueSnapshot> getQueue({
    int start = 0,
    int limit = 100,
  }) async {
    queueCalls++;
    return SABnzbdQueueSnapshot(
      status: SABnzbdStatusData(
        paused: paused,
        speed: paused ? 0 : 1,
        sizeLeft: 2,
        timeLeft: '0:00:02',
        speedlimit: 0,
      ),
      items: [
        SABnzbdQueueData(
          name: 'Shared download',
          nzoId: 'shared-job',
          sizeTotal: 4,
          sizeLeft: 2,
          status: paused ? 'Paused' : 'Downloading',
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
  Future<bool> pauseQueue() async {
    actions.add('pause');
    paused = true;
    return true;
  }

  @override
  Future<bool> pauseSingleJob(String nzoId) async {
    actions.add('pause-job:$nzoId');
    if (pauseJobResult) paused = true;
    return pauseJobResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unexpectedCalls.add(invocation.memberName);
    throw UnsupportedError(
      'Unexpected SABnzbd API call: ${invocation.memberName}',
    );
  }
}
