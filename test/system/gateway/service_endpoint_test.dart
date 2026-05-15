import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

void main() {
  test('direct hosts must be absolute HTTP URLs', () {
    expect(
      LunaServiceEndpoint.isValidDirectHost('https://radarr.example'),
      isTrue,
    );
    expect(
      LunaServiceEndpoint.isValidDirectHost('/api/radarr'),
      isFalse,
    );
    expect(
      LunaServiceEndpoint.isValidDirectHost('//radarr.example'),
      isFalse,
    );
  });

  test('gateway endpoint builds same-origin proxy URLs', () {
    const endpoint = LunaServiceEndpoint(
      module: LunaModule.RADARR,
      mode: LunaConnectionMode.gateway,
      host: '',
      gatewayProfile: 'living-room',
    );

    expect(endpoint.apiBase('api/v3/'),
        '/_lunasea/proxy/radarr/living-room/api/v3/');
  });

  test('gateway profile defaults to the shared runtime service profile', () {
    final profile = LunaProfile();

    expect(
      LunaServiceEndpoint.gatewayProfileFor(profile, LunaModule.RADARR),
      LunaProfile.DEFAULT_PROFILE,
    );
  });

  test('relative hosts stay direct setup failures instead of becoming a mode',
      () {
    final profile = LunaProfile(radarrHost: '/api/radarr');
    expect(
      profile.connectionMode(LunaModule.RADARR),
      LunaConnectionMode.direct,
    );
  });

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
