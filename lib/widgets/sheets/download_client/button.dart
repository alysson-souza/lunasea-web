import 'package:flutter/material.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/sheets/download_client/sheet.dart';
import 'package:lunasea/widgets/ui.dart';

class DownloadClientButton extends StatelessWidget {
  const DownloadClientButton({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfilesStore>().active;
    if (profile.isModuleAvailable(LunaModule.SABNZBD) ||
        profile.isModuleAvailable(LunaModule.NZBGET)) {
      return LunaIconButton.appBar(
        icon: LunaIcons.DOWNLOAD,
        onPressed: DownloadClientSheet().show,
      );
    }
    return const SizedBox();
  }
}
