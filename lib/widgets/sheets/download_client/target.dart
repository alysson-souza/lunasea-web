import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';

class DownloadClientTarget {
  final LunaServiceInstance instance;

  const DownloadClientTarget(this.instance);

  String get label => '${instance.module.title} - ${instance.displayName}';

  static List<DownloadClientTarget> available(LunaProfile profile) {
    return [
      ...profile.enabledInstances(LunaModule.SABNZBD),
      ...profile.enabledInstances(LunaModule.NZBGET),
    ].map(DownloadClientTarget.new).toList();
  }
}
