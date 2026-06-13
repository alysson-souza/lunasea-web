import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/radarr/core/consolidated_state.dart';
import 'package:lunasea/modules/radarr/core/state.dart';

void main() {
  test(
    'consolidated state refreshes merged futures when an instance notifies',
    () {
      final instance = LunaServiceInstance(
        id: 'nas-films',
        profileId: 'default',
        module: LunaModule.RADARR,
        displayName: 'NAS Films',
      );
      final instanceState = RadarrState(instance: instance);
      final consolidated = RadarrConsolidatedState(
        instances: [instance],
        instanceStates: [instanceState],
      );
      addTearDown(consolidated.dispose);

      final before = consolidated.movies;
      var notifications = 0;
      consolidated.addListener(() => notifications++);

      instanceState.moviesSearchQuery = 'matrix';

      expect(notifications, 1);
      expect(identical(consolidated.movies, before), isFalse);
    },
  );
}
