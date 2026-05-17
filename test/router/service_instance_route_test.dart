import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/router/routes.dart';

void main() {
  test('serviceInstanceFromProfile returns only enabled matching instance', () {
    final enabled = LunaServiceInstance(
      id: 'nas-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      enabled: true,
      host: 'http://radarr:7878',
    );
    final disabled = LunaServiceInstance(
      id: 'seedbox-films',
      profileId: 'default',
      module: LunaModule.RADARR,
    );
    final noHost = LunaServiceInstance(
      id: 'cloud-films',
      profileId: 'default',
      module: LunaModule.RADARR,
      enabled: true,
    );
    final sonarr = LunaServiceInstance(
      id: 'nas-tv',
      profileId: 'default',
      module: LunaModule.SONARR,
      enabled: true,
      host: 'http://sonarr:8989',
    );
    final profile = LunaProfile(
      serviceInstances: [enabled, disabled, noHost, sonarr],
    );

    final selected = serviceInstanceFromProfile(
      'nas-films',
      profile,
      LunaModule.RADARR,
    );

    expect(selected?.id, 'nas-films');
    expect(selected?.module, LunaModule.RADARR);
    expect(selected?.enabled, isTrue);
    expect(
      serviceInstanceFromProfile('seedbox-films', profile, LunaModule.RADARR),
      isNull,
    );
    expect(
      serviceInstanceFromProfile('cloud-films', profile, LunaModule.RADARR),
      isNull,
    );
    expect(
      serviceInstanceFromProfile('missing', profile, LunaModule.RADARR),
      isNull,
    );
    expect(
      serviceInstanceFromProfile('nas-tv', profile, LunaModule.RADARR),
      isNull,
    );
    expect(
      serviceInstanceFromProfile(null, profile, LunaModule.RADARR),
      isNull,
    );
  });
}
