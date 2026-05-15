import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tautulli.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationTautulliRoute extends StatefulWidget {
  const ConfigurationTautulliRoute({
    Key? key,
  }) : super(key: key);

  @override
  State<ConfigurationTautulliRoute> createState() => _State();
}

class _State extends State<ConfigurationTautulliRoute>
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
      title: LunaModule.TAUTULLI.title,
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaModule.TAUTULLI.informationBanner(),
        _enabledToggle(),
        _connectionDetailsPage(),
        LunaDivider(),
        _activityRefreshRate(),
        _defaultPagesPage(),
        _defaultTerminationMessage(),
        _statisticsItemCount(),
      ],
    );
  }

  Widget _enabledToggle() {
    return Consumer<ProfilesStore>(
      builder: (context, profiles, _) => LunaBlock(
        title: 'settings.EnableModule'.tr(args: [LunaModule.TAUTULLI.title]),
        trailing: LunaSwitch(
          value: context.watch<ProfilesStore>().active.tautulliEnabled,
          onChanged: (value) async {
            await context.read<ProfilesStore>().updateActive((profile) {
              profile.tautulliEnabled = value;
            });
            context.read<TautulliState>().reset();
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
            args: [LunaModule.TAUTULLI.title],
          ),
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_TAUTULLI_CONNECTION_DETAILS.go,
    );
  }

  Widget _defaultPagesPage() {
    return LunaBlock(
      title: 'settings.DefaultPages'.tr(),
      body: [TextSpan(text: 'settings.DefaultPagesDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_TAUTULLI_DEFAULT_PAGES.go,
    );
  }

  Widget _defaultTerminationMessage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) {
        String message = settings.tautulliTerminationMessage;
        return LunaBlock(
          title: 'tautulli.DefaultTerminationMessage'.tr(),
          body: [
            TextSpan(text: message.isEmpty ? 'lunasea.NotSet'.tr() : message),
          ],
          trailing: const LunaIconButton(icon: Icons.videocam_off_rounded),
          onTap: () async {
            Tuple2<bool, String> result =
                await TautulliDialogs.setTerminationMessage(context);
            if (result.item1) {
              await context
                  .read<SettingsStore>()
                  .setTautulliTerminationMessage(result.item2);
            }
          },
        );
      },
    );
  }

  Widget _activityRefreshRate() {
    return Consumer<SettingsStore>(builder: (context, settings, _) {
      String refreshRate = settings.tautulliRefreshRate == 1
          ? 'lunasea.EverySecond'.tr()
          : 'lunasea.EverySeconds'.tr(
              args: [settings.tautulliRefreshRate.toString()],
            );
      return LunaBlock(
        title: 'tautulli.ActivityRefreshRate'.tr(),
        body: [TextSpan(text: refreshRate)],
        trailing: const LunaIconButton(icon: LunaIcons.REFRESH),
        onTap: () async {
          List<dynamic> _values = await TautulliDialogs.setRefreshRate(context);
          if (_values[0]) {
            await context
                .read<SettingsStore>()
                .setTautulliRefreshRate(_values[1] as int);
          }
        },
      );
    });
  }

  Widget _statisticsItemCount() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) {
        String statisticsItems = settings.tautulliStatisticsItemCount == 1
            ? 'lunasea.OneItem'.tr()
            : 'lunasea.Items'.tr(
                args: [settings.tautulliStatisticsItemCount.toString()],
              );
        return LunaBlock(
          title: 'tautulli.StatisticsItemCount'.tr(),
          body: [TextSpan(text: statisticsItems)],
          trailing: const LunaIconButton(icon: Icons.format_list_numbered),
          onTap: () async {
            List<dynamic> _values =
                await TautulliDialogs.setStatisticsItemCount(context);
            if (_values[0]) {
              await context
                  .read<SettingsStore>()
                  .setTautulliStatisticsItemCount(_values[1] as int);
            }
          },
        );
      },
    );
  }
}
