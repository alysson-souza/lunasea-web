import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationRadarrRoute extends StatefulWidget {
  const ConfigurationRadarrRoute({super.key});

  @override
  State<ConfigurationRadarrRoute> createState() => _State();
}

class _State extends State<ConfigurationRadarrRoute>
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
      title: LunaModule.RADARR.title,
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaModule.RADARR.informationBanner(),
        _serviceInstancesPage(),
        LunaDivider(),
        _defaultOptionsPage(),
        _defaultPagesPage(),
        _discoverUseRadarrSuggestionsToggle(),
        _queueSize(),
      ],
    );
  }

  Widget _serviceInstancesPage() {
    return LunaBlock(
      title: 'Service Instances',
      body: [
        TextSpan(
          text: 'Configure ${LunaModule.RADARR.title} service instances.',
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () => SettingsRoutes.CONFIGURATION_SERVICE_INSTANCES.go(
        params: {'service': LunaModule.RADARR.key},
      ),
    );
  }

  Widget _defaultOptionsPage() {
    return LunaBlock(
      title: 'settings.DefaultOptions'.tr(),
      body: [TextSpan(text: 'settings.DefaultOptionsDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_RADARR_DEFAULT_OPTIONS.go,
    );
  }

  Widget _defaultPagesPage() {
    return LunaBlock(
      title: 'settings.DefaultPages'.tr(),
      body: [TextSpan(text: 'settings.DefaultPagesDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_RADARR_DEFAULT_PAGES.go,
    );
  }

  Widget _discoverUseRadarrSuggestionsToggle() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'radarr.DiscoverSuggestions'.tr(),
        body: [TextSpan(text: 'radarr.DiscoverSuggestionsDescription'.tr())],
        trailing: LunaSwitch(
          value: settings.radarrDiscoverUseSuggestions,
          onChanged: context
              .read<SettingsStore>()
              .setRadarrDiscoverUseSuggestions,
        ),
      ),
    );
  }

  Widget _queueSize() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'radarr.QueueSize'.tr(),
        body: [
          TextSpan(
            text: settings.radarrQueuePageSize == 1
                ? 'lunasea.OneItem'.tr()
                : 'lunasea.Items'.tr(
                    args: [settings.radarrQueuePageSize.toString()],
                  ),
          ),
        ],
        trailing: const LunaIconButton(icon: Icons.queue_play_next_rounded),
        onTap: () async {
          Tuple2<bool, int> result = await RadarrDialogs().setQueuePageSize(
            context,
          );
          if (result.item1) {
            await context.read<SettingsStore>().setRadarrQueuePageSize(
              result.item2,
            );
          }
        },
      ),
    );
  }
}
