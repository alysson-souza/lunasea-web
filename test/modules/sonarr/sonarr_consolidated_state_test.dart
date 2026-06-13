import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sonarr.dart';

void main() {
  test(
    'consolidated state merges missing episodes from every instance',
    () async {
      final nas = LunaServiceInstance(
        id: 'nas-tv',
        profileId: 'default',
        module: LunaModule.SONARR,
        displayName: 'NAS TV',
      );
      final seedbox = LunaServiceInstance(
        id: 'seedbox-tv',
        profileId: 'default',
        module: LunaModule.SONARR,
        displayName: 'Seedbox TV',
      );
      final nasState = SonarrState(instance: nas)
        ..missing = Future.value(
          SonarrMissing(records: [SonarrMissingRecord(id: 1, seriesId: 10)]),
        );
      final seedboxState = SonarrState(instance: seedbox)
        ..missing = Future.value(
          SonarrMissing(records: [SonarrMissingRecord(id: 2, seriesId: 20)]),
        );
      final consolidated = SonarrConsolidatedState(
        instances: [nas, seedbox],
        instanceStates: [nasState, seedboxState],
      );
      addTearDown(consolidated.dispose);

      final missing = await consolidated.missing;

      expect(missing, hasLength(2));
      expect(missing!.map((item) => item.instance.id), [
        'nas-tv',
        'seedbox-tv',
      ]);
      expect(missing.map((item) => item.item.id), [1, 2]);
    },
  );
}
