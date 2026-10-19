import 'dart:async';
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
import 'package:lunasea/modules/sabnzbd/core/consolidated_state.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/routes/consolidated_history.dart';
import 'package:lunasea/modules/sabnzbd/routes/consolidated_queue.dart';
import 'package:lunasea/modules/sabnzbd/routes/history.dart';
import 'package:lunasea/modules/sabnzbd/routes/queue.dart';
import 'package:lunasea/modules/sabnzbd/widgets/history_tile.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/widgets/ui/loader.dart';
import 'package:lunasea/widgets/ui/linear_indicator.dart';
import 'package:lunasea/widgets/ui/theme.dart';
import 'package:provider/provider.dart';

enum _Page {
  individualQueue,
  individualHistory,
  consolidatedQueue,
  consolidatedHistory;

  bool get isQueue => this == individualQueue || this == consolidatedQueue;

  bool get isConsolidated =>
      this == consolidatedQueue || this == consolidatedHistory;
}

const _jobName = 'Retained download';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> translations;

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
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
  });

  setUp(LunaBackendState.clear);
  tearDown(LunaBackendState.clear);

  for (final page in _Page.values) {
    for (final empty in [false, true]) {
      testWidgets(
        '${page.name} keeps its successful ${empty ? 'empty state' : 'content'} during a background refresh',
        (tester) async {
          final harness = await _Harness.mount(tester, translations, page);
          final initial = harness.refresh();
          await tester.pump();
          expect(_loadingIndicators(), findsOneWidget);

          harness.completeSuccess(empty: empty);
          await initial;
          await tester.pumpAndSettle();
          expect(_loadingIndicators(), findsNothing);
          expect(_paginationButtons(page), findsNothing);
          _expectJobProgress(tester, page, empty: empty);
          final completedContent = _visibleText(tester, page);
          expect(completedContent, isNotEmpty);

          final refresh = harness.refresh();
          await tester.pump();
          expect(
            _visibleText(tester, page),
            completedContent,
            reason:
                'An in-flight refresh must not replace or add visible content.',
          );
          expect(_loadingIndicators(), findsNothing);
          expect(_paginationButtons(page), findsNothing);
          _expectJobProgress(tester, page, empty: empty);

          harness.completeSuccess(empty: empty);
          await refresh;
          await tester.pumpAndSettle();
          expect(_visibleText(tester, page), completedContent);
        },
      );

      testWidgets(
        '${page.name} preserves cached records and reports failures honestly until recovery (${empty ? 'empty' : 'non-empty'})',
        (tester) async {
          final harness = await _Harness.mount(tester, translations, page);
          final initial = harness.refresh();
          harness.completeSuccess(empty: empty);
          await initial;
          await tester.pumpAndSettle();
          final completedContent = _visibleText(tester, page);

          final error = StateError('Connection was interrupted');
          final refresh = harness.refresh();
          harness.completeError(error);
          await refresh;
          await tester.pumpAndSettle();
          final failedContent = _visibleText(tester, page);
          if (page.isConsolidated && empty) {
            expect(
              find.byKey(
                ValueKey(
                  page.isQueue ? 'queue-empty' : 'sabnzbd-history-empty',
                ),
              ),
              findsNothing,
            );
          } else if (empty) {
            expect(failedContent, containsAll(completedContent));
          }
          expect(failedContent.join('\n'), contains(error.toString()));
          if (page.isConsolidated) {
            expect(
              failedContent.join('\n'),
              contains(harness.instance.displayName),
            );
          }
          expect(failedContent, isNot(completedContent));
          expect(_loadingIndicators(), findsNothing);
          _expectJobProgress(tester, page, empty: empty);

          final retry = harness.refresh();
          await tester.pump();
          expect(_visibleText(tester, page), failedContent);
          expect(_loadingIndicators(), findsNothing);
          harness.completeSuccess(empty: empty);
          await retry;
          await tester.pumpAndSettle();
          expect(_visibleText(tester, page), completedContent);
        },
      );
    }

    testWidgets(
      '${page.name} distinguishes an initial failure from a successful empty response',
      (tester) async {
        final harness = await _Harness.mount(tester, translations, page);
        final initial = harness.refresh();
        await tester.pump();
        expect(_loadingIndicators(), findsOneWidget);
        harness.completeError(StateError('Initial connection failed'));
        await initial;
        await tester.pumpAndSettle();
        expect(_loadingIndicators(), findsNothing);
        final failedContent = _visibleText(tester, page);
        expect(failedContent, isNotEmpty);

        final retry = harness.refresh();
        harness.completeSuccess(empty: true);
        await retry;
        await tester.pumpAndSettle();
        expect(_visibleText(tester, page), isNot(failedContent));
        expect(_paginationButtons(page), findsNothing);
      },
    );

    testWidgets(
      '${page.name} keeps explicit refresh feedback and loaded content',
      (tester) async {
        final harness = await _Harness.mount(tester, translations, page);
        final initial = harness.refresh();
        harness.completeSuccess();
        await initial;
        await tester.pumpAndSettle();
        final completedContent = _visibleText(tester, page);

        final refresh = harness.refreshKey.currentState!.show();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        expect(_visibleText(tester, page), completedContent);
        expect(_loadingIndicators(), findsNothing);
        _expectJobProgress(tester, page, empty: false);

        harness.completeSuccess();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await refresh;
        await tester.pumpAndSettle();
        expect(find.byType(RefreshProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      '${page.name} only offers pagination while more results remain',
      (tester) async {
        final harness = await _Harness.mount(tester, translations, page);
        final initial = harness.refresh();
        harness.completeSuccess(total: 300);
        await initial;
        await tester.pumpAndSettle();
        expect(_paginationButtons(page), findsOneWidget);
        final truncatedContent = _visibleText(tester, page);

        await tester.tap(_paginationButtons(page));
        await tester.pump();
        expect(_loadingIndicators(), findsNothing);
        _expectJobProgress(tester, page, empty: false);
        harness.completeSuccess();
        await tester.pumpAndSettle();
        expect(_paginationButtons(page), findsNothing);
        expect(_visibleText(tester, page), isNot(truncatedContent));
        _expectJobProgress(tester, page, empty: false);
      },
    );
  }

  testWidgets(
    'consolidated history waits for unresolved sources after an empty response',
    (tester) async {
      final harness = await _Harness.mount(
        tester,
        translations,
        _Page.consolidatedHistory,
        multipleSources: true,
      );
      final refresh = harness.refresh();
      harness.completeSuccess(empty: true);
      await tester.pump();

      expect(find.byKey(_historyEmptyKey), findsNothing);
      expect(find.byKey(_historyNoMatchesKey), findsNothing);
      expect(
        find.byKey(
          ValueKey(
            'sabnzbd-history-waiting:${harness.secondaryInstance.ref.key}',
          ),
        ),
        findsOneWidget,
      );
      expect(_loadingIndicators(), findsOneWidget);
      expect(
        _visibleText(tester, _Page.consolidatedHistory).join('\n'),
        contains(harness.secondaryInstance.displayName),
      );

      harness.secondaryAPI.historyRequest!.complete(_historyPage(empty: true));
      await refresh;
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'consolidated history reports the failed source instead of global empty',
    (tester) async {
      final harness = await _Harness.mount(
        tester,
        translations,
        _Page.consolidatedHistory,
        multipleSources: true,
      );
      final error = StateError('Secondary history could not be fetched');
      final refresh = harness.refresh();
      harness.completeSuccess(empty: true);
      harness.secondaryAPI.historyRequest!.completeError(error);
      await refresh;
      await tester.pumpAndSettle();

      expect(find.byKey(_historyEmptyKey), findsNothing);
      expect(find.byKey(_historyNoMatchesKey), findsNothing);
      expect(_loadingIndicators(), findsNothing);
      _expectSecondaryHistoryError(tester, harness, error);
    },
  );

  testWidgets(
    'consolidated history announces empty after every source succeeds empty',
    (tester) async {
      final harness = await _Harness.mount(
        tester,
        translations,
        _Page.consolidatedHistory,
        multipleSources: true,
      );
      final refresh = harness.refresh();
      harness.completeSuccess(empty: true);
      harness.secondaryAPI.historyRequest!.complete(_historyPage(empty: true));
      await refresh;
      await tester.pumpAndSettle();

      expect(find.byKey(_historyEmptyKey), findsOneWidget);
      expect(find.byKey(_historyNoMatchesKey), findsNothing);
      expect(_loadingIndicators(), findsNothing);
      expect(find.byType(SABnzbdHistoryTile), findsNothing);
      expect(_paginationButtons(_Page.consolidatedHistory), findsNothing);

      final backgroundRefresh = harness.refresh();
      await tester.pump();
      expect(find.byKey(_historyEmptyKey), findsOneWidget);
      expect(_loadingIndicators(), findsNothing);
      harness.completeSuccess(empty: true);
      harness.secondaryAPI.historyRequest!.complete(_historyPage(empty: true));
      await backgroundRefresh;
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'consolidated history keeps healthy records usable when another source fails',
    (tester) async {
      final harness = await _Harness.mount(
        tester,
        translations,
        _Page.consolidatedHistory,
        multipleSources: true,
      );
      final error = StateError('Secondary history connection interrupted');
      final refresh = harness.refresh();
      harness.completeSuccess();
      harness.secondaryAPI.historyRequest!.completeError(error);
      await refresh;
      await tester.pumpAndSettle();

      final tile = tester.widget<SABnzbdHistoryTile>(
        find.byKey(ValueKey('${harness.instance.ref.key}:retained-history')),
      );
      expect(tile.data.name, _jobName);
      expect(tile.sourceLabel, harness.instance.displayName);
      expect(tile.enabled, isTrue);
      expect(find.text(_jobName).hitTestable(), findsOneWidget);
      expect(find.byKey(_historyEmptyKey), findsNothing);
      expect(_loadingIndicators(), findsNothing);
      _expectSecondaryHistoryError(tester, harness, error);
    },
  );

  testWidgets(
    'consolidated history replaces source failure with recovered records',
    (tester) async {
      final harness = await _Harness.mount(
        tester,
        translations,
        _Page.consolidatedHistory,
        multipleSources: true,
      );
      final error = StateError('Secondary history temporarily unreachable');
      final initial = harness.refresh();
      harness.completeSuccess(empty: true);
      harness.secondaryAPI.historyRequest!.completeError(error);
      await initial;
      await tester.pumpAndSettle();
      _expectSecondaryHistoryError(tester, harness, error);
      final failedContent = _visibleText(tester, _Page.consolidatedHistory);

      final retry = harness.refresh();
      await tester.pump();
      expect(_visibleText(tester, _Page.consolidatedHistory), failedContent);
      expect(_loadingIndicators(), findsNothing);
      harness.completeSuccess(empty: true);
      harness.secondaryAPI.historyRequest!.complete(
        _historyPage(name: 'Recovered secondary download'),
      );
      await retry;
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey(
            'sabnzbd-history-error:${harness.secondaryInstance.ref.key}',
          ),
        ),
        findsNothing,
      );
      expect(find.byKey(_historyEmptyKey), findsNothing);
      final tile = tester.widget<SABnzbdHistoryTile>(
        find.byKey(
          ValueKey('${harness.secondaryInstance.ref.key}:retained-history'),
        ),
      );
      expect(tile.data.name, 'Recovered secondary download');
      expect(tile.sourceLabel, harness.secondaryInstance.displayName);
      expect(tile.enabled, isTrue);
      expect(find.text(tile.data.name).hitTestable(), findsOneWidget);
    },
  );

  for (final failedOnly in [false, true]) {
    testWidgets(
      'consolidated ${failedOnly ? 'failed-only filter' : 'loaded-history search'} distinguishes no matches from unknown sources',
      (tester) async {
        final harness = await _Harness.mount(
          tester,
          translations,
          _Page.consolidatedHistory,
          multipleSources: true,
        );
        if (failedOnly) {
          harness.aggregate.historyFailedOnly = true;
        } else {
          harness.aggregate.historySearchFilter = 'unmatched history query';
        }
        final refresh = harness.refresh();
        harness.completeSuccess();
        await tester.pump();

        expect(find.byKey(_historyNoMatchesKey), findsOneWidget);
        expect(find.byKey(_historyEmptyKey), findsNothing);
        expect(find.byType(SABnzbdHistoryTile), findsNothing);
        expect(
          find.byKey(
            ValueKey(
              'sabnzbd-history-waiting:${harness.secondaryInstance.ref.key}',
            ),
          ),
          findsOneWidget,
        );
        final error = StateError('Filtered source unavailable');
        harness.secondaryAPI.historyRequest!.completeError(error);
        await refresh;
        await tester.pumpAndSettle();

        expect(find.byKey(_historyNoMatchesKey), findsOneWidget);
        expect(find.byKey(_historyEmptyKey), findsNothing);
        _expectSecondaryHistoryError(tester, harness, error);
      },
    );
  }

  for (final page in [_Page.individualHistory, _Page.consolidatedHistory]) {
    testWidgets(
      '${page.name} reloads a visible reset source and ignores its obsolete read',
      (tester) async {
        final shell = await _ShellHarness.mount(tester, translations, page);
        await shell.selectTab(tester, 'history');
        expect(shell.fixture.api.historyCalls, 1);
        shell.completeHistory('Initial primary history');
        await tester.pumpAndSettle();
        expect(
          find.text('Initial primary history').hitTestable(),
          findsOneWidget,
        );

        await shell.selectTab(tester, 'queue');
        await shell.selectTab(tester, 'history');
        expect(shell.fixture.api.historyCalls, 2);
        final obsoleteRead = shell.fixture.api.historyRequest!;
        shell.completeSecondaryHistory();
        final secondaryCalls = shell.fixture.secondaryAPI.historyCalls;

        shell.fixture.state.reset();
        await shell.pumpScheduling(tester);
        expect(shell.fixture.api.historyCalls, 3);
        expect(shell.fixture.state.historyLoading, isTrue);
        expect(shell.fixture.secondaryAPI.historyCalls, secondaryCalls);
        expect(find.byType(LunaLoader).hitTestable(), findsOneWidget);

        obsoleteRead.complete(_historyPage(name: 'Obsolete primary history'));
        await shell.pumpScheduling(tester);
        expect(shell.fixture.state.history, isEmpty);
        expect(shell.fixture.state.historyLoading, isTrue);
        expect(find.text('Obsolete primary history'), findsNothing);
        expect(shell.fixture.api.historyCalls, 3);

        shell.completeHistory('Restored primary history');
        await tester.pumpAndSettle();
        expect(
          find.text('Restored primary history').hitTestable(),
          findsOneWidget,
        );
        expect(find.byType(LunaLoader).hitTestable(), findsNothing);
        for (var poll = 0; poll < 3; poll++) {
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
        }
        expect(shell.fixture.api.queueCalls, greaterThan(2));
        expect(shell.fixture.api.historyCalls, 3);
        expect(shell.fixture.secondaryAPI.historyCalls, secondaryCalls);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${page.name} waits for visibility after a hidden, covered or background reset',
      (tester) async {
        final shell = await _ShellHarness.mount(tester, translations, page);
        await shell.selectTab(tester, 'history');
        shell.completeHistory('Initial primary history');
        await tester.pumpAndSettle();

        for (final visibility in ['queue', 'covered', 'background']) {
          if (visibility == 'queue') {
            await shell.selectTab(tester, 'queue');
          } else if (visibility == 'covered') {
            showDialog<void>(
              context: LunaRouter.navigator.currentContext!,
              builder: (_) =>
                  const AlertDialog(content: Text('History is covered')),
            );
            await tester.pumpAndSettle();
          } else {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
            await tester.pump();
          }
          final beforeReset = shell.fixture.api.historyCalls;
          shell.fixture.state.reset();
          await shell.pumpScheduling(tester);
          await tester.pump(const Duration(seconds: 4));
          expect(shell.fixture.api.historyCalls, beforeReset);
          expect(shell.fixture.state.historyLoading, isFalse);

          if (visibility == 'queue') {
            await shell.selectTab(tester, 'history');
          } else if (visibility == 'covered') {
            LunaRouter.navigator.currentState!.pop();
            await shell.pumpScheduling(tester);
          } else {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await shell.pumpScheduling(tester);
          }
          expect(shell.fixture.api.historyCalls, beforeReset + 1);
          shell.completeHistory('Restored after $visibility');
          await tester.pumpAndSettle();
          expect(
            find.text('Restored after $visibility').hitTestable(),
            findsOneWidget,
          );
          expect(find.byType(LunaLoader).hitTestable(), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${page.name} does not automatically retry a failed reset read on queue polls',
      (tester) async {
        final shell = await _ShellHarness.mount(tester, translations, page);
        await shell.selectTab(tester, 'history');
        shell.completeHistory('Initial primary history');
        await tester.pumpAndSettle();

        shell.fixture.state.reset();
        await shell.pumpScheduling(tester);
        expect(shell.fixture.api.historyCalls, 2);
        final error = StateError('Reset history unavailable');
        shell.fixture.api.historyRequest!.completeError(error);
        await tester.pumpAndSettle();
        expect(shell.fixture.state.historyError, same(error));
        expect(find.byType(LunaLoader).hitTestable(), findsNothing);
        for (var poll = 0; poll < 3; poll++) {
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
        }
        expect(shell.fixture.api.historyCalls, 2);
        expect(shell.fixture.state.historyError, same(error));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _historyEmptyKey = ValueKey('sabnzbd-history-empty');
const _historyNoMatchesKey = ValueKey('sabnzbd-history-no-matches');

void _expectSecondaryHistoryError(
  WidgetTester tester,
  _Harness harness,
  Object error,
) {
  final message = find.byKey(
    ValueKey('sabnzbd-history-error:${harness.secondaryInstance.ref.key}'),
  );
  expect(message, findsOneWidget);
  final text = tester
      .widgetList<RichText>(
        find.descendant(of: message, matching: find.byType(RichText)),
      )
      .map((widget) => widget.text.toPlainText())
      .join('\n');
  expect(text, contains(harness.secondaryInstance.displayName));
  expect(text, contains(error.toString()));
}

Type _pageType(_Page page) {
  if (page.isConsolidated) {
    return page.isQueue ? SABnzbdConsolidatedQueue : SABnzbdConsolidatedHistory;
  }
  return page.isQueue ? SABnzbdQueue : SABnzbdHistory;
}

Finder _paginationButtons(_Page page) => find.descendant(
  of: find.byType(_pageType(page)),
  matching: find.byType(TextButton),
);

void _expectJobProgress(
  WidgetTester tester,
  _Page page, {
  required bool empty,
}) {
  if (empty) {
    expect(find.text(_jobName), findsNothing);
  } else {
    expect(find.text(_jobName).hitTestable().first, findsOneWidget);
    final content = _visibleText(tester, page).join('\n');
    if (page.isQueue) {
      expect(content, contains(_queueSnapshot().items.single.subtitle));
    } else {
      final job = _historyPage().items.single;
      expect(content, contains(job.statusString));
      expect(content, contains(job.sizeReadable));
      expect(content, contains(job.category));
    }
  }
  final progress = find.byType(LunaLinearPercentIndicator);
  if (page.isQueue && !empty) {
    expect(progress, findsOneWidget);
    expect(tester.widget<LunaLinearPercentIndicator>(progress).percent, 0.5);
  } else {
    expect(progress, findsNothing);
  }
}

Finder _loadingIndicators() => find.byWidgetPredicate(
  (widget) => widget is LinearProgressIndicator || widget is LunaLoader,
);

List<String> _visibleText(WidgetTester tester, _Page page) => tester
    .widgetList<RichText>(
      find.descendant(
        of: find.byType(_pageType(page)),
        matching: find.byType(RichText),
      ),
    )
    .map((widget) => widget.text.toPlainText())
    .toList();

class _Harness {
  final _Page page;
  final bool multipleSources;
  final api = _ControlledAPI();
  final controller = ScrollController();
  final refreshKey = GlobalKey<RefreshIndicatorState>();
  final instance = LunaServiceInstance(
    id: 'primary',
    profileId: 'default',
    module: LunaModule.SABNZBD,
    displayName: 'Primary Server',
    enabled: true,
    host: 'https://primary.example/',
    apiKey: 'unused-test-key',
    sortOrder: 0,
  );
  final secondaryAPI = _ControlledAPI();
  final secondaryInstance = LunaServiceInstance(
    id: 'secondary',
    profileId: 'default',
    module: LunaModule.SABNZBD,
    displayName: 'Secondary Server',
    enabled: true,
    host: 'https://secondary.example/',
    apiKey: 'unused-test-key',
    sortOrder: 1,
  );
  late final secondaryState = SABnzbdState(
    instance: secondaryInstance,
    apiClient: secondaryAPI,
  );
  late final state = SABnzbdState(instance: instance, apiClient: api);
  late final aggregate = SABnzbdConsolidatedState(
    instances: [instance, if (multipleSources) secondaryInstance],
    instanceStates: [state, if (multipleSources) secondaryState],
  );

  _Harness(this.page, {this.multipleSources = false});

  Future<void> refresh() {
    if (page.isConsolidated) {
      return page.isQueue
          ? aggregate.refreshQueue()
          : aggregate.refreshHistory();
    }
    return page.isQueue ? state.refreshQueue() : state.refreshHistory();
  }

  void completeSuccess({bool empty = false, int? total}) {
    if (page.isQueue) {
      api.queueRequest!.complete(_queueSnapshot(empty: empty, total: total));
    } else {
      api.historyRequest!.complete(_historyPage(empty: empty, total: total));
    }
  }

  void completeError(Object error) {
    if (page.isQueue) {
      api.queueRequest!.completeError(error);
    } else {
      api.historyRequest!.completeError(error);
    }
  }

  static Future<_Harness> mount(
    WidgetTester tester,
    Map<String, dynamic> translations,
    _Page page, {
    bool multipleSources = false,
  }) async {
    await LunaBackendState.hydrate({
      'preferences': {'activeProfile': 'default', 'drawerManualOrder': []},
      'profiles': [
        {'id': 'default'},
      ],
    });
    final harness = _Harness(page, multipleSources: multipleSources);
    final previousNavigator = LunaRouter.navigator;
    LunaRouter.navigator = GlobalKey<NavigatorState>();
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      harness.aggregate.dispose();
      for (final state in harness.aggregate.instanceStates) {
        state.dispose();
      }
      for (final api in [
        harness.api,
        if (multipleSources) harness.secondaryAPI,
      ]) {
        if (api.queueRequest?.isCompleted == false) {
          api.queueRequest!.complete(_queueSnapshot());
        }
        if (api.historyRequest?.isCompleted == false) {
          api.historyRequest!.complete(_historyPage(empty: true));
        }
      }
      harness.controller.dispose();
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      LunaRouter.navigator = previousNavigator;
    });
    if (!page.isQueue) {
      final queue = harness.state.refreshQueue();
      harness.api.queueRequest!.complete(_queueSnapshot());
      await queue;
      if (multipleSources) {
        final secondaryQueue = harness.secondaryState.refreshQueue();
        harness.secondaryAPI.queueRequest!.complete(_queueSnapshot());
        await secondaryQueue;
      }
    }
    final Widget child;
    if (page.isConsolidated) {
      child = page.isQueue
          ? SABnzbdConsolidatedQueue(
              refreshIndicatorKey: harness.refreshKey,
              scrollController: harness.controller,
            )
          : SABnzbdConsolidatedHistory(
              refreshIndicatorKey: harness.refreshKey,
              scrollController: harness.controller,
            );
    } else {
      child = page.isQueue
          ? SABnzbdQueue(
              refreshIndicatorKey: harness.refreshKey,
              scrollController: harness.controller,
            )
          : SABnzbdHistory(
              refreshIndicatorKey: harness.refreshKey,
              scrollController: harness.controller,
            );
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SABnzbdState>.value(value: harness.state),
          ChangeNotifierProvider<SABnzbdConsolidatedState>.value(
            value: harness.aggregate,
          ),
          ChangeNotifierProvider(create: (_) => SettingsStore()),
          ChangeNotifierProvider(create: (_) => ProfilesStore()),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/localization',
          startLocale: const Locale('en'),
          fallbackLocale: const Locale('en'),
          saveLocale: false,
          assetLoader: _EnglishAssetLoader(translations),
          child: Builder(
            builder: (context) => MaterialApp(
              navigatorKey: LunaRouter.navigator,
              theme: LunaTheme().activeTheme(),
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(body: child),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(_pageType(page)), findsOneWidget);
    return harness;
  }
}

class _ShellHarness {
  final _Harness fixture;
  late final LunaModuleStateRegistry<SABnzbdState> registry;
  late final GoRouter router;

  _ShellHarness(_Page page)
    : fixture = _Harness(page, multipleSources: page.isConsolidated) {
    fixture.api.autoCompleteQueue = true;
    fixture.secondaryAPI.autoCompleteQueue = true;
    registry = LunaModuleStateRegistry<SABnzbdState>(
      create: (instance) => instance.id == fixture.instance.id
          ? fixture.state
          : fixture.secondaryState,
    );
  }

  String get path => fixture.page.isConsolidated
      ? '/sabnzbd'
      : '/sabnzbd/${fixture.instance.id}';

  Future<void> selectTab(WidgetTester tester, String tab) async {
    router.go('$path?tab=$tab');
    await pumpScheduling(tester);
  }

  Future<void> pumpScheduling(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  void completeSecondaryHistory() {
    final request = fixture.secondaryAPI.historyRequest;
    if (request != null && !request.isCompleted) {
      request.complete(_historyPage(empty: true));
    }
  }

  void completeHistory(String name) {
    fixture.api.historyRequest!.complete(_historyPage(name: name));
    completeSecondaryHistory();
  }

  static Future<_ShellHarness> mount(
    WidgetTester tester,
    Map<String, dynamic> translations,
    _Page page,
  ) async {
    final shell = _ShellHarness(page);
    await LunaBackendState.hydrate({
      'preferences': {
        'activeProfile': 'default',
        'drawerAutomaticManage': true,
        'drawerManualOrder': [],
      },
      'profiles': [
        {'id': 'default'},
      ],
      'serviceInstances': [
        shell.fixture.instance.toJson(),
        if (page.isConsolidated) shell.fixture.secondaryInstance.toJson(),
      ],
    });
    final previousNavigator = LunaRouter.navigator;
    final previousReflect = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
    LunaRouter.navigator = GlobalKey<NavigatorState>();
    shell.router = GoRouter(
      navigatorKey: LunaRouter.navigator,
      initialLocation: '${shell.path}?tab=queue',
      overridePlatformDefaultLocation: true,
      routes: [SABnzbdRoutes.CONSOLIDATED.routes],
    );
    LunaRouter.router = shell.router;
    _resumeApplication(tester);
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      _resumeApplication(tester);
      shell.fixture.aggregate.dispose();
      shell.router.dispose();
      shell.registry.dispose();
      for (final api in [shell.fixture.api, shell.fixture.secondaryAPI]) {
        for (final request in api.historyRequests) {
          if (!request.isCompleted) request.complete(_historyPage(empty: true));
        }
      }
      shell.fixture.controller.dispose();
      await tester.pump();
      await tester.binding.setSurfaceSize(null);
      LunaRouter.navigator = previousNavigator;
      GoRouter.optionURLReflectsImperativeAPIs = previousReflect;
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LunaModuleStateRegistry<SABnzbdState>>.value(
            value: shell.registry,
          ),
          ChangeNotifierProvider(create: (_) => SettingsStore()),
          ChangeNotifierProvider(create: (_) => ProfilesStore()),
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
              routerConfig: shell.router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(shell.fixture.api.historyCalls, 0);
    return shell;
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

SABnzbdHistoryPage _historyPage({
  bool empty = false,
  int? total,
  String name = _jobName,
}) => SABnzbdHistoryPage(
  items: empty
      ? []
      : [
          SABnzbdHistoryData(
            nzoId: 'retained-history',
            name: name,
            size: 4096,
            status: 'Completed',
            failureMessage: '',
            timestamp: 1700000000,
            actionLine: '',
            category: '*',
            downloadTime: 4,
            stageLog: [],
            storageLocation: '/downloads/retained',
          ),
        ],
  total: total ?? (empty ? 0 : 1),
  start: 0,
  limit: 200,
);

SABnzbdQueueSnapshot _queueSnapshot({bool empty = false, int? total}) =>
    SABnzbdQueueSnapshot(
      status: SABnzbdStatusData(
        paused: false,
        speed: empty ? 0 : 1,
        sizeLeft: empty ? 0 : 2,
        timeLeft: '0:00:02',
        speedlimit: 0,
      ),
      items: empty
          ? []
          : [
              SABnzbdQueueData(
                name: _jobName,
                nzoId: 'retained-queue',
                sizeTotal: 4,
                sizeLeft: 2,
                status: 'Downloading',
                timeLeft: '0:00:02',
                category: '*',
              ),
            ],
      total: total ?? (empty ? 0 : 1),
      start: 0,
      limit: 100,
    );

class _EnglishAssetLoader extends AssetLoader {
  final Map<String, dynamic> translations;

  const _EnglishAssetLoader(this.translations);

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      translations;
}

class _ControlledAPI implements SABnzbdAPI {
  Completer<SABnzbdQueueSnapshot>? queueRequest;
  Completer<SABnzbdHistoryPage>? historyRequest;
  bool autoCompleteQueue = false;
  int queueCalls = 0;
  int historyCalls = 0;
  final historyRequests = <Completer<SABnzbdHistoryPage>>[];

  @override
  Future<SABnzbdQueueSnapshot> getQueue({int start = 0, int limit = 100}) {
    queueCalls++;
    queueRequest = Completer<SABnzbdQueueSnapshot>();
    if (autoCompleteQueue) queueRequest!.complete(_queueSnapshot());
    return queueRequest!.future;
  }

  @override
  Future<SABnzbdHistoryPage> getHistoryPage({int start = 0, int limit = 200}) {
    historyCalls++;
    historyRequest = Completer<SABnzbdHistoryPage>();
    historyRequests.add(historyRequest!);
    return historyRequest!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected SABnzbd API call: ${invocation.memberName}',
  );
}
