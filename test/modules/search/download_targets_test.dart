import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/search/core/download_target.dart';
import 'package:lunasea/modules/search/core/types/download_type.dart';

void main() {
  test('search download targets include each enabled client instance', () {
    final profile = LunaProfile(
      serviceInstances: [
        LunaServiceInstance(
          id: 'nzbget-a',
          module: LunaModule.NZBGET,
          displayName: 'NZBGet A',
          enabled: true,
        ),
        LunaServiceInstance(
          id: 'nzbget-b',
          module: LunaModule.NZBGET,
          displayName: 'NZBGet B',
          enabled: true,
        ),
        LunaServiceInstance(
          id: 'sab-off',
          module: LunaModule.SABNZBD,
          displayName: 'SAB Off',
        ),
        LunaServiceInstance(
          id: 'sab-on',
          module: LunaModule.SABNZBD,
          displayName: 'SAB On',
          enabled: true,
        ),
      ],
    );

    final targets = SearchDownloadTarget.available(profile);

    expect(targets.map((target) => target.type), [
      SearchDownloadType.SABNZBD,
      SearchDownloadType.NZBGET,
      SearchDownloadType.NZBGET,
      SearchDownloadType.FILESYSTEM,
    ]);
    expect(targets.map((target) => target.instance?.id), [
      'sab-on',
      'nzbget-a',
      'nzbget-b',
      null,
    ]);
    expect(targets.map((target) => target.label), [
      'SABnzbd - SAB On',
      'NZBGet - NZBGet A',
      'NZBGet - NZBGet B',
      SearchDownloadType.FILESYSTEM.name,
    ]);
  });
}
