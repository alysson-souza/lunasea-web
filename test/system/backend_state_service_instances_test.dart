import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/backend_state.dart';

void main() {
  tearDown(LunaBackendState.clear);

  test('hydrates service instances onto profiles', () async {
    await LunaBackendState.hydrate({
      'preferences': {'drawerManualOrder': []},
      'profiles': [
        {'id': 'default'},
      ],
      'serviceInstances': [
        {
          'id': 'nas',
          'profile': 'default',
          'service': 'radarr',
          'displayName': 'NAS',
          'enabled': true,
          'sortOrder': 1,
        },
        {
          'id': 'off',
          'profile': 'default',
          'service': 'radarr',
          'displayName': 'Off',
          'enabled': false,
          'sortOrder': 2,
        },
      ],
    });

    final profile = LunaBackendState.profiles['default']!;

    expect(profile.serviceInstances.length, 2);
    expect(profile.enabledInstances(LunaModule.RADARR).map((i) => i.id), [
      'nas',
    ]);
    expect(profile.radarrEnabled, isTrue);
  });

  test('hydrates default service instances when profiles are absent', () async {
    await LunaBackendState.hydrate({
      'preferences': {'drawerManualOrder': []},
      'serviceInstances': [
        {
          'id': 'default',
          'profile': 'default',
          'service': 'radarr',
          'displayName': 'Default Radarr',
          'enabled': true,
        },
      ],
    });

    final profile = LunaBackendState.profiles['default']!;

    expect(profile.serviceInstances.map((instance) => instance.id), [
      'default',
    ]);
    expect(profile.radarrEnabled, isTrue);
  });

  test(
    'hydrates default service instances when profiles and profile field are absent',
    () async {
      await LunaBackendState.hydrate({
        'preferences': {'drawerManualOrder': []},
        'serviceInstances': [
          {
            'id': 'default',
            'service': 'radarr',
            'displayName': 'Default Radarr',
            'enabled': true,
          },
        ],
      });

      final profile = LunaBackendState.profiles['default']!;

      expect(profile.serviceInstances.map((instance) => instance.id), [
        'default',
      ]);
      expect(profile.radarrEnabled, isTrue);
    },
  );

  test(
    'empty serviceInstances does not fall back to legacy serviceConnections',
    () async {
      await LunaBackendState.hydrate({
        'preferences': {'drawerManualOrder': []},
        'profiles': [
          {'id': 'default'},
        ],
        'serviceInstances': [],
        'serviceConnections': [
          {'profile': 'default', 'service': 'radarr'},
        ],
      });

      final profile = LunaBackendState.profiles['default']!;
      expect(profile.serviceInstances, isEmpty);
      expect(profile.radarrEnabled, isFalse);
    },
  );

  test('hydrate ignores malformed service instance records', () async {
    await LunaBackendState.hydrate({
      'preferences': {'drawerManualOrder': []},
      'profiles': [
        {'id': 'default'},
        'not-a-map',
      ],
      'serviceInstances': [
        'not-a-map',
        {'profile': 'default', 'service': 'unsupported', 'id': 'bad'},
        {
          'profile': 'default',
          'service': 'radarr',
          'id': 'good',
          'displayName': 'Good',
          'enabled': true,
          'sortOrder': 'not-a-number',
        },
      ],
    });

    final profile = LunaBackendState.profiles['default']!;
    expect(profile.serviceInstances.map((instance) => instance.id), ['good']);
  });
}
