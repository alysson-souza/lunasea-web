import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/router/router.dart';

void main() {
  test('initialLocationFromUri returns route fragment', () {
    expect(
      initialLocationFromUri(
        Uri.parse('http://127.0.0.1:8080/#/radarr?tab=missing'),
      ),
      '/radarr?tab=missing',
    );
  });

  test('initialLocationFromUri returns path and query', () {
    expect(
      initialLocationFromUri(
        Uri.parse('http://127.0.0.1:8080/dashboard?tab=calendar'),
      ),
      '/dashboard?tab=calendar',
    );
  });

  test('initialLocationFromUri ignores root route', () {
    expect(initialLocationFromUri(Uri.parse('http://127.0.0.1:8080/')), isNull);
  });

  testWidgets('router uses non-root browser path as initial location', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/settings';
    addTearDown(() {
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
    });

    LunaRouter().initialize(initialUri: Uri.parse('http://localhost/settings'));
    addTearDown(LunaRouter.router.dispose);

    expect(
      LunaRouter.router.routeInformationProvider.value.uri.toString(),
      '/settings',
    );
  });
}
