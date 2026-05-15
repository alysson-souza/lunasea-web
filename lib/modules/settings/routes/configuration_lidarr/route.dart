import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/lidarr.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationLidarrRoute extends StatefulWidget {
  const ConfigurationLidarrRoute({
    Key? key,
  }) : super(key: key);

  @override
  State<ConfigurationLidarrRoute> createState() => _State();
}

class _State extends State<ConfigurationLidarrRoute>
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
      title: LunaModule.LIDARR.title,
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaModule.LIDARR.informationBanner(),
        _enabledToggle(),
        _connectionDetailsPage(),
        LunaDivider(),
        _defaultPagesPage(),
        //_defaultPagesPage(),
      ],
    );
  }

  Widget _enabledToggle() {
    return Consumer<ProfilesStore>(
      builder: (context, profiles, _) => LunaBlock(
        title: 'settings.EnableModule'.tr(args: [LunaModule.LIDARR.title]),
        trailing: LunaSwitch(
          value: context.watch<ProfilesStore>().active.lidarrEnabled,
          onChanged: (value) async {
            await context.read<ProfilesStore>().updateActive((profile) {
              profile.lidarrEnabled = value;
            });
            context.read<LidarrState>().reset();
          },
        ),
      ),
    );
  }

  Widget _connectionDetailsPage() {
    return LunaBlock(
      title: 'settings.ConnectionDetails'.tr(),
      body: [
        TextSpan(
          text: 'settings.ConnectionDetailsDescription'.tr(
            args: [LunaModule.LIDARR.title],
          ),
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_LIDARR_CONNECTION_DETAILS.go,
    );
  }

  Widget _defaultPagesPage() {
    return LunaBlock(
      title: 'settings.DefaultPages'.tr(),
      body: [TextSpan(text: 'settings.DefaultPagesDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_LIDARR_DEFAULT_PAGES.go,
    );
  }
}
