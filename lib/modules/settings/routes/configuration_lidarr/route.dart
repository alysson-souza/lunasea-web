import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationLidarrRoute extends StatefulWidget {
  const ConfigurationLidarrRoute({super.key});

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
        _serviceInstancesPage(),
        LunaDivider(),
        _defaultPagesPage(),
        //_defaultPagesPage(),
      ],
    );
  }

  Widget _serviceInstancesPage() {
    return LunaBlock(
      title: 'Service Instances',
      body: [
        TextSpan(
          text: 'Configure ${LunaModule.LIDARR.title} service instances.',
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () => SettingsRoutes.CONFIGURATION_SERVICE_INSTANCES.go(
        params: {'service': LunaModule.LIDARR.key},
      ),
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
