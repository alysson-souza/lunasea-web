import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(LunaBackendState.clear);

  testWidgets('Radarr instance route uses the instance name as its title', (
    tester,
  ) async {
    final instance = LunaServiceInstance(
      id: 'nas-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      displayName: 'NAS Films',
      enabled: false,
    );

    await _hydrate();
    await tester.pumpWidget(
      _testApp(
        ChangeNotifierProvider(create: (_) => RadarrState(instance: instance)),
        RadarrRoute(instance: instance),
      ),
    );

    expect(find.text('Radarr - NAS Films'), findsOneWidget);
  });

  testWidgets('Sonarr instance route uses the instance name as its title', (
    tester,
  ) async {
    final instance = LunaServiceInstance(
      id: 'nas-tv',
      profileId: 'default',
      module: LunaModule.SONARR,
      displayName: 'NAS TV',
      enabled: false,
    );

    await _hydrate();
    await tester.pumpWidget(
      _testApp(
        ChangeNotifierProvider(create: (_) => SonarrState(instance: instance)),
        SonarrRoute(instance: instance),
      ),
    );

    expect(find.text('Sonarr - NAS TV'), findsOneWidget);
  });
}

Future<void> _hydrate() {
  return LunaBackendState.hydrate({
    'preferences': {
      'activeProfile': 'default',
      'drawerAutomaticManage': true,
      'drawerManualOrder': [],
    },
    'profiles': [
      {'id': 'default'},
    ],
  });
}

Widget _testApp<T extends ChangeNotifier>(
  ChangeNotifierProvider<T> provider,
  Widget child,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ProfilesStore()),
      ChangeNotifierProvider(create: (_) => IndexersStore()),
      ChangeNotifierProvider(create: (_) => ExternalModulesStore()),
      ChangeNotifierProvider(create: (_) => SettingsStore()),
      provider,
    ],
    child: MaterialApp(home: child),
  );
}
