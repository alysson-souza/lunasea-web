import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lunasea/router/routes.dart';

void main() {
  testWidgets('tabIndexFromRoute returns matching tab index', (tester) async {
    late int selected;
    final router = _router(
      initialLocation: '/dashboard?tab=calendar',
      onBuild: (state) {
        selected = tabIndexFromRoute(state, const [
          'modules',
          'calendar',
        ], fallback: 0);
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(selected, 1);
  });

  testWidgets('tabIndexFromRoute falls back for unknown tab', (tester) async {
    late int selected;
    final router = _router(
      initialLocation: '/dashboard?tab=unknown',
      onBuild: (state) {
        selected = tabIndexFromRoute(state, const [
          'modules',
          'calendar',
        ], fallback: 1);
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(selected, 1);
  });
}

GoRouter _router({
  required String initialLocation,
  required void Function(GoRouterState state) onBuild,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, state) {
          onBuild(state);
          return const SizedBox.shrink();
        },
      ),
    ],
  );
}
