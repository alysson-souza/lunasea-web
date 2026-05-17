import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/settings/core/service_instance_settings.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';

void main() {
  group('SettingsServiceInstanceSettings', () {
    test(
      'newDraft uses module title, next sort order, and enables instance',
      () {
        final draft = SettingsServiceInstanceSettings.newDraft(
          'profile-a',
          LunaModule.RADARR,
          [
            LunaServiceInstance(
              id: 'radarr-1',
              profileId: 'profile-a',
              module: LunaModule.RADARR,
              sortOrder: 0,
            ),
            LunaServiceInstance(
              id: 'radarr-2',
              profileId: 'profile-a',
              module: LunaModule.RADARR,
              sortOrder: 4,
            ),
          ],
        );

        expect(draft.id, isEmpty);
        expect(draft.profileId, 'profile-a');
        expect(draft.module, LunaModule.RADARR);
        expect(draft.displayName, LunaModule.RADARR.title);
        expect(draft.enabled, isTrue);
        expect(draft.sortOrder, 5);
        expect(draft.connectionMode, LunaConnectionMode.gateway.key);
      },
    );

    test('newDraft starts sort order at zero when there are no instances', () {
      final draft = SettingsServiceInstanceSettings.newDraft(
        'profile-a',
        LunaModule.SONARR,
        const [],
      );

      expect(draft.sortOrder, 0);
    });
  });
}
