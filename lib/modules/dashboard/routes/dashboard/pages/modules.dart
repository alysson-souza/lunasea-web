import 'package:flutter/material.dart';

import 'package:lunasea/modules.dart';
import 'package:lunasea/system/preferences/lunasea.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/modules/dashboard/routes/dashboard/widgets/navigation_bar.dart';

class ModulesPage extends StatefulWidget {
  const ModulesPage({
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ModulesPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _list();
  }

  Widget _list() {
    final profiles = context.watch<ProfilesStore>();
    if (!LunaModule.active.any(profiles.isEnabled)) {
      return LunaMessage(
        text: 'lunasea.NoModulesEnabled'.tr(),
        buttonText: 'lunasea.GoToSettings'.tr(),
        onTap: LunaModule.SETTINGS.launch,
      );
    }
    return LunaListView(
      controller: HomeNavigationBar.scrollControllers[0],
      itemExtent: LunaBlock.calculateItemExtent(1),
      children: LunaSeaPreferences.DRAWER_AUTOMATIC_MANAGE.read()
          ? _buildAlphabeticalList(profiles)
          : _buildManuallyOrderedList(profiles),
    );
  }

  List<Widget> _buildAlphabeticalList(ProfilesStore profiles) {
    List<Widget> modules = [];
    int index = 0;
    LunaModule.active
      ..sort((a, b) => a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          ))
      ..forEach((module) {
        if (profiles.isEnabled(module)) {
          modules.add(_buildFromLunaModule(module, index));
          index++;
        }
      });
    modules.add(_buildFromLunaModule(LunaModule.SETTINGS, index));
    return modules;
  }

  List<Widget> _buildManuallyOrderedList(ProfilesStore profiles) {
    List<Widget> modules = [];
    int index = 0;
    LunaDrawer.moduleOrderedList().forEach((module) {
      if (profiles.isEnabled(module)) {
        modules.add(_buildFromLunaModule(module, index));
        index++;
      }
    });
    modules.add(_buildFromLunaModule(LunaModule.SETTINGS, index));
    return modules;
  }

  Widget _buildFromLunaModule(LunaModule module, int listIndex) {
    return LunaBlock(
      title: module.title,
      body: [TextSpan(text: module.description)],
      trailing: LunaIconButton(icon: module.icon, color: module.color),
      onTap: module.launch,
    );
  }
}
