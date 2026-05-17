import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/system/gateway/gateway.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

void main() {
  tearDown(() => LunaGateway.state.clear());

  test('serviceInstance resolves by profile service and instance ids', () {
    final instance = LunaServiceInstance(
      id: 'nas-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      displayName: 'NAS Films',
      enabled: true,
    );
    LunaGateway.state['serviceInstances'] = [instance.toJson()];

    final service = LunaGateway.serviceInstance(instance.ref);

    expect(service?['id'], 'nas-films');
    expect(service?['enabled'], isTrue);
  });

  test(
    'merge keeps cached disabled instances missing from filtered service response',
    () {
      LunaGateway.state['serviceInstances'] = [
        LunaServiceInstance(
          id: 'disabled',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'Disabled',
        ).toJson(),
      ];

      LunaGateway.mergeServiceInstancesForTest([
        LunaServiceInstance(
          id: 'enabled',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'Enabled',
          enabled: true,
          host: 'https://radarr.example',
        ).toJson(),
      ]);

      final services = LunaGateway.state['serviceInstances'] as List;
      expect(services.map((service) => service['id']), ['disabled', 'enabled']);
    },
  );

  test('merge updates cached instance by service profile and id identity', () {
    LunaGateway.state['serviceInstances'] = [
      LunaServiceInstance(
        id: 'nas-films',
        profileId: 'default',
        module: LunaModule.RADARR,
        displayName: 'Old Name',
        enabled: true,
      ).toJson(),
      LunaServiceInstance(
        id: 'nas-films',
        profileId: 'other',
        module: LunaModule.RADARR,
        displayName: 'Other Profile',
        enabled: true,
      ).toJson(),
    ];

    LunaGateway.mergeServiceInstancesForTest([
      LunaServiceInstance(
        id: 'nas-films',
        profileId: 'default',
        module: LunaModule.RADARR,
        displayName: 'New Name',
        enabled: true,
      ).toJson(),
    ]);

    final services = LunaGateway.state['serviceInstances'] as List;
    expect(services.length, 2);
    expect(
      services.singleWhere(
        (service) => service['profile'] == 'default',
      )['displayName'],
      'New Name',
    );
    expect(
      services.singleWhere(
        (service) => service['profile'] == 'other',
      )['displayName'],
      'Other Profile',
    );
  });

  test('create service instance payload omits client generated id', () {
    final data = LunaGateway.serviceCreateDataForTest(
      displayName: 'NAS Films',
      enabled: true,
      upstreamUrl: 'https://radarr.example',
      apiKey: 'secret',
    );

    expect(data, isNot(contains('id')));
    expect(data['displayName'], 'NAS Films');
    expect(data['upstreamUrl'], 'https://radarr.example');
  });

  test('instance helper paths include profile service and instance ids', () {
    const ref = LunaServiceInstanceRef(
      profileId: 'default',
      module: LunaModule.RADARR,
      instanceId: 'nas-films',
    );

    expect(
      LunaGateway.instancePathForTest(ref),
      'profiles/default/services/radarr/instances/nas-films',
    );
    expect(
      LunaGateway.instanceTestPathForTest(ref),
      'profiles/default/services/radarr/instances/nas-films/test',
    );
  });

  test(
    'applying service response upserts profile instance for endpoint resolution',
    () {
      final profile = LunaProfile();

      LunaGateway.applyServiceInstanceToProfileForTest(profile, {
        'id': 'nas-films',
        'profile': 'default',
        'service': 'radarr',
        'displayName': 'NAS Films',
        'enabled': true,
        'connectionMode': LunaConnectionMode.gateway.key,
        'upstreamUrl': 'https://radarr.example',
      });

      expect(profile.serviceInstances, hasLength(1));

      final endpoint = LunaServiceEndpoint.fromProfile(
        profile,
        LunaModule.RADARR,
      );

      expect(endpoint.instanceId, 'nas-films');
    },
  );

  test('removing service instance from profile clears matching instance', () {
    final profile = LunaProfile(
      serviceInstances: [
        LunaServiceInstance(
          id: 'nas-films',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'NAS Films',
          enabled: true,
        ),
      ],
    );

    LunaGateway.removeServiceInstanceFromProfileForTest(
      profile,
      const LunaServiceInstanceRef(
        profileId: 'default',
        module: LunaModule.RADARR,
        instanceId: 'nas-films',
      ),
    );

    expect(profile.serviceInstances, isEmpty);
  });

  test(
    'profile module refs derive from profile instances when gateway cache is empty',
    () {
      final profile = LunaProfile(
        key: 'default',
        serviceInstances: [
          LunaServiceInstance(
            id: 'disabled',
            profileId: 'default',
            module: LunaModule.RADARR,
          ),
          LunaServiceInstance(
            id: 'incomplete',
            profileId: 'default',
            module: LunaModule.RADARR,
            enabled: true,
          ),
          LunaServiceInstance(
            id: 'sonarr',
            profileId: 'default',
            module: LunaModule.SONARR,
          ),
        ],
      );

      final refs = LunaGateway.profileServiceRefsForTest(
        profile,
        LunaModule.RADARR,
      );

      expect(refs.map((ref) => ref.instanceId), ['disabled', 'incomplete']);
    },
  );

  test('removing profile module refs removes all matching instances', () {
    final profile = LunaProfile(
      key: 'default',
      serviceInstances: [
        LunaServiceInstance(
          id: 'disabled',
          profileId: 'default',
          module: LunaModule.RADARR,
        ),
        LunaServiceInstance(
          id: 'incomplete',
          profileId: 'default',
          module: LunaModule.RADARR,
          enabled: true,
        ),
        LunaServiceInstance(
          id: 'sonarr',
          profileId: 'default',
          module: LunaModule.SONARR,
        ),
      ],
    );

    LunaGateway.removeProfileServiceRefsForTest(profile, LunaModule.RADARR);

    expect(profile.serviceInstances.map((instance) => instance.id), ['sonarr']);
  });

  test(
    'delete profile service ref clears profile and cache on missing backend instance',
    () async {
      final profile = LunaProfile(
        key: 'default',
        serviceInstances: [
          LunaServiceInstance(
            id: 'nas-films',
            profileId: 'default',
            module: LunaModule.RADARR,
            enabled: true,
          ),
        ],
      );
      final ref = profile.serviceInstances.single.ref;
      LunaGateway.state['serviceInstances'] = [
        profile.serviceInstances.single.toJson(),
      ];
      final requestOptions = RequestOptions(
        path: LunaGateway.instancePathForTest(ref),
      );

      await LunaGateway.deleteServiceRefFromProfileForTest(
        profile,
        ref,
        (_) async => throw DioException(
          requestOptions: requestOptions,
          response: Response<void>(
            requestOptions: requestOptions,
            statusCode: 404,
          ),
        ),
      );

      expect(profile.serviceInstances, isEmpty);
      expect(LunaGateway.state['serviceInstances'], isEmpty);
    },
  );
}
