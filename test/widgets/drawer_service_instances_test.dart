import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/widgets/ui/drawer/drawer.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(LunaBackendState.clear);

  testWidgets('drawer lists enabled service instances', (tester) async {
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
        LunaServiceInstance(
          id: 'nas-films',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'NAS Films',
          enabled: true,
        ).toJson(),
        LunaServiceInstance(
          id: 'seedbox-films',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'Seedbox Films',
          enabled: true,
        ).toJson(),
      ],
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfilesStore()),
          ChangeNotifierProvider(create: (_) => IndexersStore()),
          ChangeNotifierProvider(create: (_) => ExternalModulesStore()),
          ChangeNotifierProvider(create: (_) => SettingsStore()),
        ],
        child: MaterialApp(
          home: Scaffold(
            drawer: const LunaDrawer(page: 'dashboard'),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: Scaffold.of(context).openDrawer,
                child: const Text('Open drawer'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    expect(find.text('Radarr - NAS Films'), findsOneWidget);
    expect(find.text('Radarr - Seedbox Films'), findsOneWidget);
  });

  testWidgets('drawer omits scalar service module fallback entries', (
    tester,
  ) async {
    LunaBackendState.profiles['default'] = LunaProfile();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfilesStore()),
          ChangeNotifierProvider(create: (_) => IndexersStore()),
          ChangeNotifierProvider(create: (_) => ExternalModulesStore()),
          ChangeNotifierProvider(create: (_) => SettingsStore()),
        ],
        child: MaterialApp(
          home: Scaffold(
            drawer: const LunaDrawer(page: 'dashboard'),
            body: Builder(
              builder: (context) => TextButton(
                onPressed: Scaffold.of(context).openDrawer,
                child: const Text('Open drawer'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    expect(find.text('Radarr'), findsNothing);
  });
}
