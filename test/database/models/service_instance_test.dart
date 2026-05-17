import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';

void main() {
  test('service instance round trips through JSON', () {
    final instance = LunaServiceInstance(
      id: 'nas-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      displayName: 'NAS Films',
      enabled: true,
      sortOrder: 10,
      connectionMode: LunaConnectionMode.gateway.key,
      host: 'https://radarr.example',
      apiKey: 'secret',
      headers: {'X-Test': 'yes'},
      preferences: {'rootFolderId': 1},
    );

    final copy = LunaServiceInstance.fromJson(instance.toJson());

    expect(copy.id, 'nas-films');
    expect(copy.profileId, 'default');
    expect(copy.module, LunaModule.RADARR);
    expect(copy.displayName, 'NAS Films');
    expect(copy.enabled, isTrue);
    expect(copy.headers, {'X-Test': 'yes'});
    expect(copy.preferences['rootFolderId'], 1);
  });

  test('profile exposes enabled instances by module', () {
    final profile = LunaProfile(
      key: 'default',
      serviceInstances: [
        LunaServiceInstance(
          id: 'nas',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'NAS',
          enabled: true,
        ),
        LunaServiceInstance(
          id: 'off',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'Off',
          enabled: false,
        ),
      ],
    );

    expect(profile.enabledInstances(LunaModule.RADARR).map((i) => i.id), [
      'nas',
    ]);
    expect(profile.isModuleAvailable(LunaModule.RADARR), isTrue);
    expect(profile.isModuleAvailable(LunaModule.SONARR), isFalse);
  });

  test('service instance preserves redacted credential presence flags', () {
    final instance = LunaServiceInstance.fromJson({
      'id': 'nas-films',
      'profile': 'default',
      'service': 'radarr',
      'displayName': 'NAS Films',
      'hasApiKey': true,
      'hasUsername': true,
      'hasPassword': true,
    });

    expect(instance.apiKey, isEmpty);
    expect(instance.username, isEmpty);
    expect(instance.password, isEmpty);
    expect(instance.hasApiKey, isTrue);
    expect(instance.hasUsername, isTrue);
    expect(instance.hasPassword, isTrue);

    final copy = LunaServiceInstance.fromJson(instance.toJson());
    expect(copy.hasApiKey, isTrue);
    expect(copy.hasUsername, isTrue);
    expect(copy.hasPassword, isTrue);
  });

  test(
    'service instance omits empty redacted credentials from JSON payloads',
    () {
      final redacted = LunaServiceInstance.fromJson({
        'id': 'nas-films',
        'profile': 'default',
        'service': 'radarr',
        'hasApiKey': true,
        'hasUsername': true,
        'hasPassword': true,
      }).toJson();

      expect(redacted.containsKey('apiKey'), isFalse);
      expect(redacted.containsKey('username'), isFalse);
      expect(redacted.containsKey('password'), isFalse);
      expect(redacted['hasApiKey'], isTrue);
      expect(redacted['hasUsername'], isTrue);
      expect(redacted['hasPassword'], isTrue);

      final explicit = LunaServiceInstance(
        id: 'nas-films',
        module: LunaModule.RADARR,
        apiKey: 'secret',
        username: 'user',
        password: 'pass',
      ).toJson();

      expect(explicit['apiKey'], 'secret');
      expect(explicit['username'], 'user');
      expect(explicit['password'], 'pass');
    },
  );

  test('profile fromJson ignores malformed service instance entries', () {
    final profile = LunaProfile.fromJson({
      'key': 'default',
      'serviceInstances': [
        'not-a-map',
        {'profile': 'default', 'service': 'unsupported', 'id': 'bad'},
        {
          'profile': 'default',
          'service': 'radarr',
          'id': 'good',
          'sortOrder': 'not-a-number',
        },
      ],
    });

    expect(profile.serviceInstances.map((instance) => instance.id), ['good']);
  });

  test('profile clone deep copies nested service instance preferences', () {
    final profile = LunaProfile(
      key: 'default',
      serviceInstances: [
        LunaServiceInstance(
          id: 'nas',
          profileId: 'default',
          module: LunaModule.RADARR,
          preferences: {
            'quality': {
              'profiles': [1],
            },
          },
        ),
      ],
    );

    final clone = LunaProfile.clone(profile);
    final originalProfiles =
        profile.serviceInstances.first.preferences['quality']['profiles']
            as List<dynamic>;
    originalProfiles.add(2);

    final cloneProfiles =
        clone.serviceInstances.first.preferences['quality']['profiles']
            as List<dynamic>;
    expect(cloneProfiles, [1]);
  });

  test('service instance refs compare by profile module and instance id', () {
    const ref = LunaServiceInstanceRef(
      profileId: 'default',
      module: LunaModule.RADARR,
      instanceId: 'nas',
    );

    expect(
      ref,
      const LunaServiceInstanceRef(
        profileId: 'default',
        module: LunaModule.RADARR,
        instanceId: 'nas',
      ),
    );
    expect({ref}, contains(ref));
  });

  test('profile constructor defensively copies service instances', () {
    final source = [
      LunaServiceInstance(
        id: 'nas',
        profileId: 'default',
        module: LunaModule.RADARR,
        headers: {'X-Test': 'yes'},
        preferences: {
          'quality': {
            'profiles': [1],
          },
        },
      ),
    ];

    final profile = LunaProfile(key: 'default', serviceInstances: source);
    source.add(
      LunaServiceInstance(
        id: 'other',
        profileId: 'default',
        module: LunaModule.RADARR,
      ),
    );
    source.first.headers['X-Test'] = 'no';
    final sourceProfiles =
        source.first.preferences['quality']['profiles'] as List<dynamic>;
    sourceProfiles.add(2);

    expect(profile.serviceInstances.map((instance) => instance.id), ['nas']);
    expect(profile.serviceInstances.first.headers, {'X-Test': 'yes'});
    expect(profile.serviceInstances.first.preferences['quality']['profiles'], [
      1,
    ]);
  });

  test('instancesFor uses id as final deterministic tie-breaker', () {
    final profile = LunaProfile(
      key: 'default',
      serviceInstances: [
        LunaServiceInstance(
          id: 'b',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'NAS',
        ),
        LunaServiceInstance(
          id: 'a',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'nas',
        ),
      ],
    );

    expect(
      profile.instancesFor(LunaModule.RADARR).map((instance) => instance.id),
      ['a', 'b'],
    );
  });
}
