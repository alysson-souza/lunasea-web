import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lunasea/widgets/ui.dart';

void main() {
  testWidgets('bottom navigation writes selected tab to the URL', (
    tester,
  ) async {
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => Scaffold(
            bottomNavigationBar: LunaBottomNavigationBar(
              pageController: PageController(),
              icons: const [
                Icons.workspaces_rounded,
                Icons.calendar_today_rounded,
              ],
              titles: const ['Modules', 'Calendar'],
              tabKeys: const ['modules', 'calendar'],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byIcon(Icons.calendar_today_rounded).last);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/dashboard?tab=calendar',
    );
  });
}
