import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';

void main() {
  tearDown(LunaBackendState.clear);

  test('service instances make module enabled', () async {
    await LunaBackendState.hydrate({
      'preferences': {'enabledProfile': 'default', 'drawerManualOrder': []},
      'profiles': [
        {'id': 'default'},
      ],
      'serviceInstances': [
        LunaServiceInstance(
          id: 'nas-films',
          profileId: 'default',
          module: LunaModule.RADARR,
          enabled: true,
        ).toJson(),
      ],
    });

    expect(ProfilesStore().isEnabled(LunaModule.RADARR), isTrue);
  });

  test('disabled-only service instances make module disabled', () async {
    await LunaBackendState.hydrate({
      'preferences': {'enabledProfile': 'default', 'drawerManualOrder': []},
      'profiles': [
        {'id': 'default'},
      ],
      'serviceInstances': [
        LunaServiceInstance(
          id: 'nas-films',
          profileId: 'default',
          module: LunaModule.RADARR,
        ).toJson(),
      ],
    });

    expect(ProfilesStore().isEnabled(LunaModule.RADARR), isFalse);
  });

  test(
    'enabledInstanceRefs returns enabled refs for a profile and module',
    () async {
      await LunaBackendState.hydrate({
        'preferences': {'enabledProfile': 'default', 'drawerManualOrder': []},
        'profiles': [
          {'id': 'default'},
        ],
        'serviceInstances': [
          LunaServiceInstance(
            id: 'enabled',
            profileId: 'default',
            module: LunaModule.RADARR,
            enabled: true,
          ).toJson(),
          LunaServiceInstance(
            id: 'disabled',
            profileId: 'default',
            module: LunaModule.RADARR,
          ).toJson(),
          LunaServiceInstance(
            id: 'sonarr',
            profileId: 'default',
            module: LunaModule.SONARR,
            enabled: true,
          ).toJson(),
        ],
      });

      expect(
        ProfilesStore().enabledInstanceRefs('default', LunaModule.RADARR),
        [
          const LunaServiceInstanceRef(
            profileId: 'default',
            module: LunaModule.RADARR,
            instanceId: 'enabled',
          ),
        ],
      );
    },
  );
}
