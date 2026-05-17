import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationSABnzbdRoute extends StatefulWidget {
  const ConfigurationSABnzbdRoute({super.key});

  @override
  State<ConfigurationSABnzbdRoute> createState() => _State();
}

class _State extends State<ConfigurationSABnzbdRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar(),
      body: _body(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar(
      title: LunaModule.SABNZBD.title,
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaModule.SABNZBD.informationBanner(),
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
          text: 'Configure ${LunaModule.SABNZBD.title} service instances.',
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () => SettingsRoutes.CONFIGURATION_SERVICE_INSTANCES.go(
        params: {'service': LunaModule.SABNZBD.key},
      ),
    );
  }

  Widget _defaultPagesPage() {
    return LunaBlock(
      title: 'settings.DefaultPages'.tr(),
      body: [TextSpan(text: 'settings.DefaultPagesDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_SABNZBD_DEFAULT_PAGES.go,
    );
  }
}
