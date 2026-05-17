import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/nzbget.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/sheets/download_client/sheet.dart';
import 'package:lunasea/widgets/sheets/download_client/target.dart';

void main() {
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
              builder: (context) => Text(
                context.read<NZBGetState>().instance?.id ?? '',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('nzbget-two'), findsOneWidget);
  });

  testWidgets('download client route provides selected SABnzbd instance state', (
    tester,
  ) async {
    final instance = LunaServiceInstance(
      id: 'sab-two',
      module: LunaModule.SABNZBD,
      displayName: 'SAB Two',
      enabled: true,
      host: 'https://sab-two.example',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfilesStore>(
        create: (_) => ProfilesStore(),
        child: MaterialApp(
          home: DownloadClientSheet().routeForTarget(
            DownloadClientTarget(instance),
            child: Builder(
              builder: (context) => Text(
                context.read<SABnzbdState>().instance?.id ?? '',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('sab-two'), findsOneWidget);
  });
}
