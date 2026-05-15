import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/system/quick_actions/quick_actions.dart';

class ConfigurationQuickActionsRoute extends StatefulWidget {
  const ConfigurationQuickActionsRoute({
    Key? key,
  }) : super(key: key);

  @override
  State<ConfigurationQuickActionsRoute> createState() => _State();
}

class _State extends State<ConfigurationQuickActionsRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar() as PreferredSizeWidget?,
      body: _body(),
    );
  }

  Widget _appBar() {
    return LunaAppBar(
      scrollControllers: [scrollController],
      title: 'settings.QuickActions'.tr(),
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        SettingsBanners.QUICK_ACTIONS_SUPPORT.banner(),
        _actionTile(LunaModule.LIDARR),
        _actionTile(LunaModule.NZBGET),
        if (LunaModule.OVERSEERR.featureFlag) _actionTile(LunaModule.OVERSEERR),
        _actionTile(LunaModule.RADARR),
        _actionTile(LunaModule.SABNZBD),
        _actionTile(LunaModule.SEARCH),
        _actionTile(LunaModule.SONARR),
        _actionTile(LunaModule.TAUTULLI),
      ],
    );
  }

  Widget _actionTile(LunaModule module) {
    return LunaBlock(
      title: module.title,
      trailing: Consumer<SettingsStore>(
        builder: (context, settings, _) => LunaSwitch(
          value: settings.quickActionEnabled(module),
          onChanged: (value) async {
            await settings.setQuickActionEnabled(module, value);
            if (LunaQuickActions.isSupported)
              LunaQuickActions().setActionItems();
          },
        ),
      ),
    );
  }
}
