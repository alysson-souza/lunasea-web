import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationSonarrRoute extends StatefulWidget {
  const ConfigurationSonarrRoute({super.key});

  @override
  State<ConfigurationSonarrRoute> createState() => _State();
}

class _State extends State<ConfigurationSonarrRoute>
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
      title: LunaModule.SONARR.title,
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaModule.SONARR.informationBanner(),
        _serviceInstancesPage(),
        LunaDivider(),
        _defaultOptionsPage(),
        _defaultPagesPage(),
        _queueSize(),
      ],
    );
  }

  Widget _serviceInstancesPage() {
    return LunaBlock(
      title: 'Service Instances',
      body: [
        TextSpan(
          text: 'Configure ${LunaModule.SONARR.title} service instances.',
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () => SettingsRoutes.CONFIGURATION_SERVICE_INSTANCES.go(
        params: {'service': LunaModule.SONARR.key},
      ),
    );
  }

  Widget _defaultPagesPage() {
    return LunaBlock(
      title: 'settings.DefaultPages'.tr(),
      body: [TextSpan(text: 'settings.DefaultPagesDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_SONARR_DEFAULT_PAGES.go,
    );
  }

  Widget _defaultOptionsPage() {
    return LunaBlock(
      title: 'settings.DefaultOptions'.tr(),
      body: [TextSpan(text: 'settings.DefaultOptionsDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_SONARR_DEFAULT_OPTIONS.go,
    );
  }

  Widget _queueSize() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'sonarr.QueueSize'.tr(),
        body: [
          TextSpan(
            text: settings.sonarrQueuePageSize == 1
                ? 'lunasea.OneItem'.tr()
                : 'lunasea.Items'.tr(
                    args: [settings.sonarrQueuePageSize.toString()],
                  ),
          ),
        ],
        trailing: const LunaIconButton(icon: Icons.queue_play_next_rounded),
        onTap: () async {
          Tuple2<bool, int> result = await SonarrDialogs().setQueuePageSize(
            context,
          );
          if (result.item1) {
            await context.read<SettingsStore>().setSonarrQueuePageSize(
              result.item2,
            );
          }
        },
      ),
    );
  }
}
