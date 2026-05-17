import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

void main() {
  test('direct hosts must be absolute HTTP URLs', () {
    expect(
      LunaServiceEndpoint.isValidDirectHost('https://radarr.example'),
      isTrue,
    );
    expect(LunaServiceEndpoint.isValidDirectHost('/api/radarr'), isFalse);
    expect(LunaServiceEndpoint.isValidDirectHost('//radarr.example'), isFalse);
  });

  test(
    'gateway endpoint without explicit instance uses default instance segment',
    () {
      const endpoint = LunaServiceEndpoint(
        module: LunaModule.RADARR,
        mode: LunaConnectionMode.gateway,
        host: '',
        profileId: 'default',
      );

      expect(
        endpoint.apiBase('api/v3/'),
        '/_lunasea/proxy/radarr/default/default/api/v3/',
      );
    },
  );

  test('gateway endpoint builds same-origin proxy URLs with instance id', () {
    const endpoint = LunaServiceEndpoint(
      module: LunaModule.RADARR,
      mode: LunaConnectionMode.gateway,
      host: '',
      profileId: 'default',
      instanceId: 'nas-films',
    );

    expect(
      endpoint.apiBase('api/v3/'),
      '/_lunasea/proxy/radarr/default/nas-films/api/v3/',
    );
  });

  test('fromProfile prefers enabled service instance endpoint', () {
    final profile = LunaProfile(
      serviceInstances: [
        LunaServiceInstance(
          id: 'nas-films',
          profileId: 'default',
          module: LunaModule.RADARR,
          displayName: 'NAS Films',
          enabled: true,
          host: 'https://radarr.example',
        ),
      ],
    );

    final endpoint = LunaServiceEndpoint.fromProfile(
      profile,
      LunaModule.RADARR,
    );

    expect(endpoint.base, 'https://radarr.example');
    expect(endpoint.instanceId, 'nas-films');
  });

  test('gateway profile defaults to the shared runtime service profile', () {
    final profile = LunaProfile();

    expect(
      LunaServiceEndpoint.gatewayProfileFor(profile, LunaModule.RADARR),
      LunaProfile.DEFAULT_PROFILE,
    );
  });

  test(
    'relative hosts stay direct setup failures instead of becoming a mode',
    () {
      final profile = LunaProfile(radarrHost: '/api/radarr');
      expect(
        profile.connectionMode(LunaModule.RADARR),
        LunaConnectionMode.direct,
      );
    },
  );

  test('stored gateway mode falls back when capabilities are absent', () {
    final profile = LunaProfile(
      radarrConnectionMode: LunaConnectionMode.gateway.key,
      radarrHost: 'https://radarr.example',
    );
    expect(
      profile.connectionMode(LunaModule.RADARR),
      LunaConnectionMode.direct,
    );
  });
}
