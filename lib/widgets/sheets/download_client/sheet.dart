import 'package:flutter/material.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/nzbget.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/pages/invalid_route.dart';
import 'package:lunasea/widgets/sheets/download_client/target.dart';
import 'package:lunasea/widgets/ui.dart';

class DownloadClientSheet extends LunaBottomModalSheet {
  Future<DownloadClientTarget?> getDownloadClient() async {
    final profile = LunaState.context.read<ProfilesStore>().active;
    final targets = DownloadClientTarget.available(profile);

    if (targets.length <= 1) return targets.isEmpty ? null : targets.single;
    return _selectDownloadClient(targets);
  }

  @override
  Future<dynamic> show({Widget Function(BuildContext context)? builder}) async {
    final target = await getDownloadClient();
    if (target != null) {
      return showModal(
        builder: (context) => routeForTarget(target),
      );
    }
  }

  @visibleForTesting
  Widget routeForTarget(DownloadClientTarget target, {Widget? child}) {
    final module = target.instance.module;
    if (module == LunaModule.SABNZBD) {
      return ChangeNotifierProvider<SABnzbdState>(
        create: (_) => SABnzbdState(instance: target.instance),
        child:
            child ?? SABnzbdRoute(instance: target.instance, showDrawer: false),
      );
    }
    if (module == LunaModule.NZBGET) {
      return ChangeNotifierProvider<NZBGetState>(
        create: (_) => NZBGetState(instance: target.instance),
        child: child ?? NZBGetRoute(instance: target.instance, showDrawer: false),
      );
    }
    return InvalidRoutePage();
  }

  Future<DownloadClientTarget?> _selectDownloadClient(
    List<DownloadClientTarget> targets,
  ) async {
    DownloadClientTarget? selected;
    await LunaDialog.dialog(
      context: LunaState.context,
      title: 'lunasea.DownloadClient'.tr(),
      content: [
        for (final entry in targets.asMap().entries)
          LunaDialog.tile(
            text: entry.value.label,
            icon: entry.value.instance.module.icon,
            iconColor: LunaColours().byListIndex(entry.key),
            onTap: () {
              selected = entry.value;
              Navigator.of(LunaState.context).pop();
            },
          ),
      ],
      contentPadding: LunaDialog.listDialogContentPadding(),
    );
    return selected;
  }
}
