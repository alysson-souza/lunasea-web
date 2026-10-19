import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lunasea/modules/sabnzbd/core/api.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/snapshot.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/widgets/polling_scope.dart';

const _pollInterval = Duration(seconds: 2);

void main() {
  testWidgets('only the exact visible shell owns a single polling loop', (
    tester,
  ) async {
    final first = _Source();
    final second = _Source();
    final harness = _Harness([first.state, second.state]);
    await harness.mount(tester);

    expect(first.api.queueCalls, 1);
    expect(second.api.queueCalls, 1);
    await tester.pump(_pollInterval);
    expect(first.api.queueCalls, 2);
    expect(second.api.queueCalls, 2);

    final beforeInstance = first.api.queueCalls;
    harness.router.push('/sabnzbd/primary?tab=history');
    await tester.pumpAndSettle();
    expect(first.api.queueCalls, beforeInstance + 1);
    final coveredSecondCalls = second.api.queueCalls;
    final instanceCalls = first.api.queueCalls;
    await tester.pump(_pollInterval);
    expect(first.api.queueCalls, instanceCalls + 1);
    expect(second.api.queueCalls, coveredSecondCalls);

    for (final path in ['statistics', 'history/job-1']) {
      harness.router.push('/sabnzbd/primary/$path');
      await tester.pumpAndSettle();
      final stoppedCalls = first.api.queueCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(first.api.queueCalls, stoppedCalls);
      expect(second.api.queueCalls, coveredSecondCalls);

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(first.api.queueCalls, stoppedCalls + 1);
    }

    final beforeRoot = first.api.queueCalls;
    harness.router.pop();
    await tester.pumpAndSettle();
    expect(first.api.queueCalls, beforeRoot + 1);
    expect(second.api.queueCalls, coveredSecondCalls + 1);
    final resumedFirstCalls = first.api.queueCalls;
    final resumedSecondCalls = second.api.queueCalls;
    await tester.pump(_pollInterval);
    expect(first.api.queueCalls, resumedFirstCalls + 1);
    expect(second.api.queueCalls, resumedSecondCalls + 1);

    harness.router.go('/outside');
    await tester.pumpAndSettle();
    final stoppedFirst = first.api.queueCalls;
    final stoppedSecond = second.api.queueCalls;
    await tester.pump(const Duration(seconds: 6));
    expect(first.api.queueCalls, stoppedFirst);
    expect(second.api.queueCalls, stoppedSecond);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visible handoff coalesces with an in-flight source request', (
    tester,
  ) async {
    final source = _Source();
    final harness = _Harness([source.state]);
    await harness.mount(tester);
    expect(source.api.queueCalls, 1);

    final barrier = Completer<void>();
    source.api.queueBarrier = barrier;
    harness.router.push('/sabnzbd/primary');
    await tester.pumpAndSettle();
    expect(source.api.queueCalls, 2);

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(source.api.queueCalls, 2);

    source.api.queueBarrier = null;
    barrier.complete();
    await tester.pumpAndSettle();
    expect(source.api.queueCalls, 2);
    await tester.pump(_pollInterval);
    expect(source.api.queueCalls, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab changes and rebuilt duplicate membership never reacquire', (
    tester,
  ) async {
    final source = _Source();
    final harness = _Harness([source.state, source.state]);
    await harness.mount(tester);
    expect(source.api.queueCalls, 1);

    harness.router.go('/sabnzbd?tab=history');
    harness.states.value = [source.state];
    await tester.pumpAndSettle();
    expect(source.api.queueCalls, 1);
    await tester.pump(_pollInterval);
    expect(source.api.queueCalls, 2);

    harness.router.go('/outside');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(source.api.queueCalls, 2);
  });

  testWidgets('membership replacement releases removed and disposed sources', (
    tester,
  ) async {
    final removed = _Source();
    final disposed = _Source();
    final retained = _Source();
    final replacement = _Source();
    final harness = _Harness([removed.state, disposed.state, retained.state]);
    await harness.mount(tester);

    harness.states.value = [retained.state, replacement.state];
    disposed.state.dispose();
    await tester.pumpAndSettle();
    expect(removed.api.queueCalls, 1);
    expect(retained.api.queueCalls, 1);
    expect(replacement.api.queueCalls, 1);
    expect(tester.takeException(), isNull);

    await tester.pump(_pollInterval);
    expect(disposed.api.queueCalls, 1);
    expect(removed.api.queueCalls, 1);
    expect(retained.api.queueCalls, 2);
    expect(replacement.api.queueCalls, 2);

    harness.states.value = [];
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(retained.api.queueCalls, 2);
    expect(replacement.api.queueCalls, 2);
    expect(disposed.api.queueCalls, 1);
  });

  testWidgets('background states stop demand and resume fetches fresh once', (
    tester,
  ) async {
    final source = _Source();
    final harness = _Harness([source.state]);
    await harness.mount(tester);

    for (final lifecycle in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(lifecycle);
      await tester.pump();
      final stoppedCalls = source.api.queueCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(source.api.queueCalls, stoppedCalls);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(source.api.queueCalls, stoppedCalls + 1);
      await tester.pump(_pollInterval);
      expect(source.api.queueCalls, stoppedCalls + 2);
    }
  });

  testWidgets('resume cannot poll a covered scope or newly replaced member', (
    tester,
  ) async {
    final original = _Source();
    final replacement = _Source();
    final harness = _Harness([original.state]);
    await harness.mount(tester);

    harness.router.push('/sabnzbd/primary/statistics');
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    harness.states.value = [replacement.state];
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(original.api.queueCalls, 1);
    expect(replacement.api.queueCalls, 0);

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(original.api.queueCalls, 1);
    expect(replacement.api.queueCalls, 1);
  });

  testWidgets('source replacement during build safely publishes after build', (
    tester,
  ) async {
    final original = _Source();
    final replacement = _Source();
    final harness = _Harness([original.state]);
    await harness.mount(tester);

    harness.states.value = [replacement.state];
    await tester.pumpAndSettle();
    expect(find.text('Queue requests: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    final calls = replacement.api.queueCalls;
    harness.router.go('/sabnzbd?tab=history');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 6));
    expect(original.api.queueCalls, 1);
    expect(replacement.api.queueCalls, calls);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covering the exact full-page URL releases its polling demand', (
    tester,
  ) async {
    final source = _Source();
    final harness = _Harness([source.state]);
    await harness.mount(tester);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      showDialog<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(content: Text('Covering full page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(harness.router.routeInformationProvider.value.uri.path, '/sabnzbd');
    final coveredCalls = source.api.queueCalls;
    await tester.pump(const Duration(seconds: 6));
    expect(source.api.queueCalls, coveredCalls);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(source.api.queueCalls, coveredCalls + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'current popup polls without changing its containing module URL',
    (tester) async {
      final source = _Source();
      final harness = _Harness([source.state]);
      await harness.mount(tester);
      harness.router.go('/outside');
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      final beforeOpen = source.api.queueCalls;
      unawaited(
        showModalBottomSheet<void>(
          context: navigator.context,
          builder: (_) => SABnzbdPollingScope(
            states: [source.state],
            routePath: '/sabnzbd/primary',
            child: const SizedBox(height: 200, child: Text('Embedded queue')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/outside',
      );
      expect(source.api.queueCalls, beforeOpen + 1);
      await tester.pump(_pollInterval);
      expect(source.api.queueCalls, beforeOpen + 2);

      unawaited(
        showDialog<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('Covering dialog')),
        ),
      );
      await tester.pumpAndSettle();
      final coveredCalls = source.api.queueCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 6));
      expect(source.api.queueCalls, coveredCalls);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(source.api.queueCalls, coveredCalls + 1);
      navigator.pop();
      await tester.pumpAndSettle();
      final closedCalls = source.api.queueCalls;
      await tester.pump(const Duration(seconds: 6));
      expect(source.api.queueCalls, closedCalls);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('post-frame route changes defer demand reconciliation safely', (
    tester,
  ) async {
    final source = _Source();
    final harness = _Harness([source.state]);
    await harness.mount(tester);

    harness.redirectDuringBuild.value = true;
    await tester.pumpAndSettle();
    final calls = source.api.queueCalls;
    await tester.pump(const Duration(seconds: 6));
    expect(source.api.queueCalls, calls);
    expect(find.text('Outside SABnzbd'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Source {
  final api = _QueueAPI();
  late final state = SABnzbdState(apiClient: api, pollInterval: _pollInterval);

  _Source() {
    addTearDown(() {
      if (!state.isDisposed) state.dispose();
    });
  }
}

class _QueueAPI implements SABnzbdAPI {
  int queueCalls = 0;
  Completer<void>? queueBarrier;

  @override
  Future<SABnzbdQueueSnapshot> getQueue({
    int start = 0,
    int limit = 100,
  }) async {
    queueCalls++;
    final barrier = queueBarrier;
    if (barrier != null) await barrier.future;
    return SABnzbdQueueSnapshot(
      status: SABnzbdStatusData(
        paused: false,
        speed: 10,
        sizeLeft: 20,
        timeLeft: '0:00:02',
        speedlimit: 0,
      ),
      items: [],
      total: 0,
      start: start,
      limit: limit,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  final ValueNotifier<List<SABnzbdState>> states;
  final redirectDuringBuild = ValueNotifier(false);
  late final GoRouter router;

  _Harness(List<SABnzbdState> sources) : states = ValueNotifier(sources) {
    final previousReflect = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
    addTearDown(() {
      GoRouter.optionURLReflectsImperativeAPIs = previousReflect;
      router.dispose();
      states.dispose();
      redirectDuringBuild.dispose();
    });
    router = GoRouter(
      initialLocation: '/sabnzbd',
      routes: [
        GoRoute(
          path: '/outside',
          pageBuilder: (_, route) => NoTransitionPage(
            key: route.pageKey,
            child: const Text('Outside SABnzbd'),
          ),
        ),
        GoRoute(
          path: '/sabnzbd',
          pageBuilder: (_, route) => NoTransitionPage(
            key: route.pageKey,
            child: ValueListenableBuilder<List<SABnzbdState>>(
              valueListenable: states,
              builder: (_, sources, __) => ValueListenableBuilder<bool>(
                valueListenable: redirectDuringBuild,
                builder: (_, redirect, __) {
                  if (redirect) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      scheduleMicrotask(() => router.go('/outside'));
                    });
                  }
                  return SABnzbdPollingScope(
                    states: sources,
                    routePath: '/sabnzbd',
                    child: _QueueStatus(states: sources),
                  );
                },
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: ':instanceId',
              pageBuilder: (_, route) => NoTransitionPage(
                key: route.pageKey,
                child: ValueListenableBuilder<List<SABnzbdState>>(
                  valueListenable: states,
                  builder: (_, sources, __) => SABnzbdPollingScope(
                    states: sources.take(1).toList(),
                    routePath: '/sabnzbd/${route.pathParameters['instanceId']}',
                    child: const Text('Individual queue'),
                  ),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'statistics',
                  pageBuilder: (_, route) => NoTransitionPage(
                    key: route.pageKey,
                    child: const Text('Statistics'),
                  ),
                ),
                GoRoute(
                  path: 'history/:job',
                  pageBuilder: (_, route) => NoTransitionPage(
                    key: route.pageKey,
                    child: const Text('History detail'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }
}

class _QueueStatus extends StatelessWidget {
  final List<SABnzbdState> states;

  const _QueueStatus({required this.states});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(states),
    builder: (_, __) => Text(
      'Queue requests: ${states.where((state) => state.status != null).length}',
    ),
  );
}
