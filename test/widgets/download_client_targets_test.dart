import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/nzbget.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/snapshot.dart';
import 'package:lunasea/modules/sabnzbd/widgets/history_tile.dart';
import 'package:lunasea/modules/sabnzbd/widgets/navigation_bar.dart';
import 'package:lunasea/modules/sabnzbd/widgets/queue_tile.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/sheets/download_client/sheet.dart';
import 'package:lunasea/widgets/sheets/download_client/target.dart';
import 'package:lunasea/widgets/ui/theme.dart';

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

  setUp(LunaBackendState.clear);
  tearDown(LunaBackendState.clear);

  test(
    'download client targets enumerate enabled NZBGet and SABnzbd instances',
    () {
      final profile = LunaProfile(
        serviceInstances: [
          LunaServiceInstance(
            id: 'sab-one',
            module: LunaModule.SABNZBD,
            displayName: 'SAB One',
            enabled: true,
          ),
          LunaServiceInstance(
            id: 'nzbget-one',
            module: LunaModule.NZBGET,
            displayName: 'NZBGet One',
            enabled: true,
          ),
          LunaServiceInstance(
            id: 'nzbget-off',
            module: LunaModule.NZBGET,
            displayName: 'NZBGet Off',
          ),
        ],
      );

      final targets = DownloadClientTarget.available(profile);

      expect(targets.map((target) => target.instance.id), [
        'sab-one',
        'nzbget-one',
      ]);
      expect(targets.map((target) => target.label), [
        'SABnzbd - SAB One',
        'NZBGet - NZBGet One',
      ]);
    },
  );

  testWidgets('download client route provides selected NZBGet instance state', (
    tester,
  ) async {
    final instance = LunaServiceInstance(
      id: 'nzbget-two',
      module: LunaModule.NZBGET,
      displayName: 'NZBGet Two',
      enabled: true,
      host: 'https://nzbget-two.example',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfilesStore>(
        create: (_) => ProfilesStore(),
        child: MaterialApp(
          home: DownloadClientSheet().routeForTarget(
            DownloadClientTarget(instance),
            child: Builder(
              builder: (context) =>
                  Text(context.read<NZBGetState>().instance?.id ?? ''),
            ),
          ),
        ),
      ),
    );

    expect(find.text('nzbget-two'), findsOneWidget);
  });

  testWidgets(
    'download client route provides selected SABnzbd instance state',
    (tester) async {
      final instance = LunaServiceInstance(
        id: 'sab-two',
        module: LunaModule.SABNZBD,
        displayName: 'SAB Two',
        enabled: true,
        host: 'https://sab-two.example',
      );

      await LunaBackendState.hydrate({
        'preferences': {'activeProfile': 'default', 'drawerManualOrder': []},
        'profiles': [
          {'id': 'default'},
        ],
        'serviceInstances': [instance.toJson()],
      });
      final registry = LunaModuleStateRegistry<SABnzbdState>(
        create: (instance) => SABnzbdState(instance: instance),
      );
      addTearDown(registry.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ProfilesStore()),
            ChangeNotifierProvider<LunaModuleStateRegistry<SABnzbdState>>.value(
              value: registry,
            ),
          ],
          child: MaterialApp(
            home: DownloadClientSheet().routeForTarget(
              DownloadClientTarget(instance),
              child: Builder(
                builder: (context) =>
                    Text(context.read<SABnzbdState>().instance?.id ?? ''),
              ),
            ),
          ),
        ),
      );

      expect(find.text('sab-two'), findsOneWidget);
      expect(
        tester.element(find.text('sab-two')).read<SABnzbdState>(),
        same(registry.get(instance)),
      );
    },
  );
  for (final path in ['/search', '/sonarr', '/radarr']) {
    testWidgets('actual SAB sheet loads and releases its source from $path', (
      tester,
    ) async {
      final harness = await _SheetHarness.mount(tester, translations, path);
      await harness.open(tester);
      final selected = harness.registry.get(harness.instances.last);
      final api = harness.apis['sab-two']!;
      expect(harness.router.routeInformationProvider.value.uri.path, path);
      expect(find.text('SAB Two queue').hitTestable(), findsOneWidget);
      expect(
        tester
            .element(find.byType(SABnzbdQueueTile).hitTestable())
            .read<SABnzbdState>(),
        same(selected),
      );
      expect(api.queueCalls, 1);
      expect(harness.apis['sab-one']!.queueCalls, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(api.queueCalls, 2);

      final callerLocation = harness.router.routeInformationProvider.value.uri;
      await tester.tap(
        find.descendant(
          of: find.byType(SABnzbdNavigationBar),
          matching: find.byWidgetPredicate(
            (widget) => widget is GButton && widget.text == 'History',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SAB Two history').hitTestable(), findsOneWidget);
      expect(
        tester
            .element(find.byType(SABnzbdHistoryTile).hitTestable())
            .read<SABnzbdState>(),
        same(selected),
      );
      expect(api.historyCalls, 1);
      expect(harness.apis['sab-one']!.historyCalls, 0);
      expect(harness.router.routeInformationProvider.value.uri, callerLocation);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      final backgroundCalls = api.queueCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(api.queueCalls, backgroundCalls);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.queueCalls, backgroundCalls + 1);

      unawaited(
        showDialog<void>(
          context: LunaRouter.navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Covering sheet')),
        ),
      );
      await tester.pumpAndSettle();
      final coveredCalls = api.queueCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(api.queueCalls, coveredCalls);
      LunaRouter.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(api.queueCalls, coveredCalls + 1);
      expect(find.text('SAB Two history').hitTestable(), findsOneWidget);

      LunaRouter.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SABnzbdRoute), findsNothing);
      expect(find.text('Open downloads'), findsOneWidget);
      expect(selected.isDisposed, isFalse);
      final dismissedCalls = api.queueCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(api.queueCalls, dismissedCalls);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('actual sheet selector closes modal and preserves History', (
    tester,
  ) async {
    final harness = await _SheetHarness.mount(tester, translations, '/search');
    await harness.open(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SABnzbdNavigationBar),
        matching: find.byWidgetPredicate(
          (widget) => widget is GButton && widget.text == 'History',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch Instance').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('All Instances').last,
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.toString(),
      '/sabnzbd?tab=history',
    );
    expect(find.text('SAB One history').hitTestable(), findsOneWidget);
    expect(find.text('SAB Two history').hitTestable(), findsOneWidget);
    expect(find.byType(SABnzbdRoute), findsNothing);

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/search');
    expect(find.text('Open downloads'), findsOneWidget);
    expect(find.byType(SABnzbdRoute), findsNothing);
    final stoppedCalls = harness.apis.values
        .map((api) => api.queueCalls)
        .toList();
    await tester.pump(const Duration(seconds: 6));
    expect(harness.apis.values.map((api) => api.queueCalls), stoppedCalls);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual sheet rebinds a replaced source and releases demand', (
    tester,
  ) async {
    final harness = await _SheetHarness.mount(tester, translations, '/search');
    await harness.open(tester);
    final original = harness.registry.get(harness.instances.last);
    final originalAPI = harness.apis['sab-two']!;
    final originalCalls = originalAPI.queueCalls;
    final replacement = LunaServiceInstance(
      id: 'sab-two',
      module: LunaModule.SABNZBD,
      displayName: 'Replacement SAB',
      enabled: true,
      host: 'https://replacement.invalid',
      sortOrder: 1,
    );
    final replacementAPI = _SheetAPI('Replacement SAB');
    harness.apis['sab-two'] = replacementAPI;

    await harness.configure([harness.instances.first, replacement]);
    await tester.pumpAndSettle();
    expect(original.isDisposed, isTrue);
    expect(find.text('SAB Two queue'), findsNothing);
    expect(find.text('Replacement SAB queue').hitTestable(), findsOneWidget);
    final current = tester
        .element(find.byType(SABnzbdQueueTile).hitTestable())
        .read<SABnzbdState>();
    expect(current.instance?.host, replacement.host);
    expect(current.isDisposed, isFalse);
    expect(replacementAPI.queueCalls, 1);
    expect(harness.created.map((instance) => instance.host), [
      harness.instances.last.host,
      replacement.host,
    ]);
    await tester.pump(const Duration(seconds: 2));
    expect(originalAPI.queueCalls, originalCalls);
    expect(replacementAPI.queueCalls, 2);

    LunaRouter.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    final dismissedCalls = replacementAPI.queueCalls;
    await tester.pump(const Duration(seconds: 6));
    expect(replacementAPI.queueCalls, dismissedCalls);
    expect(current.isDisposed, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final change in ['removed', 'disabled', 'hostless', 'profile']) {
    testWidgets('actual sheet stops its source when target is $change', (
      tester,
    ) async {
      final harness = await _SheetHarness.mount(
        tester,
        translations,
        '/search',
      );
      await harness.open(tester);
      final original = harness.registry.get(harness.instances.last);
      final originalAPI = harness.apis['sab-two']!;
      final originalCalls = originalAPI.queueCalls;
      final unavailable = LunaServiceInstance(
        id: 'sab-two',
        profileId: change == 'profile' ? 'other' : 'default',
        module: LunaModule.SABNZBD,
        displayName: 'Unavailable SAB',
        enabled: change != 'disabled',
        host: change == 'hostless' ? '' : 'https://other.invalid',
      );
      final otherAPI = _SheetAPI('Unavailable SAB');
      harness.apis['sab-two'] = otherAPI;

      await harness.configure(
        [
          if (change != 'profile') harness.instances.first,
          if (change != 'removed') unavailable,
        ],
        activeProfile: change == 'profile' ? 'other' : 'default',
        syncRegistry: change != 'profile',
      );
      await tester.pumpAndSettle();
      expect(original.isDisposed, change != 'profile');
      expect(find.byType(SABnzbdRoute), findsNothing);
      expect(find.byType(SABnzbdQueueTile), findsNothing);
      expect(find.text('Unavailable SAB queue'), findsNothing);
      expect(harness.router.routeInformationProvider.value.uri.path, '/search');
      await tester.pump(const Duration(seconds: 6));
      expect(originalAPI.queueCalls, originalCalls);
      expect(otherAPI.queueCalls, 0);
      expect(
        harness.created.where(
          (instance) => instance.host == harness.instances.last.host,
        ),
        hasLength(1),
      );

      LunaRouter.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open downloads'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

void _resumeApplication(WidgetTester tester) {
  final binding = tester.binding;
  if (binding.lifecycleState == AppLifecycleState.paused) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (binding.lifecycleState == AppLifecycleState.hidden) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  if (binding.lifecycleState != AppLifecycleState.resumed) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}

class _SheetHarness {
  final profiles = ProfilesStore();
  final instances = [
    LunaServiceInstance(
      id: 'sab-one',
      module: LunaModule.SABNZBD,
      displayName: 'SAB One',
      enabled: true,
      host: 'https://sab-one.invalid',
    ),
    LunaServiceInstance(
      id: 'sab-two',
      module: LunaModule.SABNZBD,
      displayName: 'SAB Two',
      enabled: true,
      host: 'https://sab-two.invalid',
      sortOrder: 1,
    ),
  ];
  final apis = <String, _SheetAPI>{};
  final created = <LunaServiceInstance>[];
  late final LunaModuleStateRegistry<SABnzbdState> registry;
  late final GoRouter router;

  _SheetHarness() {
    registry = LunaModuleStateRegistry<SABnzbdState>(
      create: (instance) {
        created.add(instance);
        return SABnzbdState(instance: instance, apiClient: apis[instance.id]!);
      },
    );
    for (final instance in instances) {
      apis[instance.id] = _SheetAPI(instance.displayName);
    }
  }

  Future<void> configure(
    List<LunaServiceInstance> instances, {
    String activeProfile = 'default',
    bool syncRegistry = true,
  }) async {
    await LunaBackendState.hydrate({
      'preferences': {'activeProfile': activeProfile, 'drawerManualOrder': []},
      'profiles': [
        for (final id in {'default', activeProfile}) {'id': id},
      ],
      'serviceInstances': instances
          .map((instance) => instance.toJson())
          .toList(),
    });
    if (syncRegistry) {
      registry.sync(profiles.active.instancesFor(LunaModule.SABNZBD));
    }
    profiles.refresh();
  }

  static Future<_SheetHarness> mount(
    WidgetTester tester,
    Map<String, dynamic> translations,
    String path,
  ) async {
    final harness = _SheetHarness();
    await LunaBackendState.hydrate({
      'preferences': {'activeProfile': 'default', 'drawerManualOrder': []},
      'profiles': [
        {'id': 'default'},
      ],
      'serviceInstances': harness.instances
          .map((instance) => instance.toJson())
          .toList(),
    });
    LunaRouter.navigator = GlobalKey<NavigatorState>();
    harness.router = GoRouter(
      navigatorKey: LunaRouter.navigator,
      initialLocation: path,
      overridePlatformDefaultLocation: true,
      routes: [
        for (final path in ['/search', '/sonarr', '/radarr'])
          GoRoute(
            path: path,
            builder: (_, __) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => unawaited(DownloadClientSheet().show()),
                  child: const Text('Open downloads'),
                ),
              ),
            ),
          ),
        SABnzbdRoutes.CONSOLIDATED.routes,
      ],
    );
    LunaRouter.router = harness.router;
    _resumeApplication(tester);
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      _resumeApplication(tester);
      await tester.pump();
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
          assetLoader: _SheetAssetLoader(translations),
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

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SABnzbd - SAB Two'));
    await tester.pumpAndSettle();
  }
}

class _SheetAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _SheetAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations;
}

class _SheetAPI implements SABnzbdAPI {
  final String label;
  int queueCalls = 0;
  int historyCalls = 0;

  _SheetAPI(this.label);

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
      items: [
        SABnzbdHistoryData(
          nzoId: 'shared-job',
          name: '$label history',
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
      ],
      total: 1,
      start: start,
      limit: limit,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
