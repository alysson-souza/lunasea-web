import 'package:flutter/material.dart';
import 'package:lunasea/vendor.dart';

import 'package:lunasea/modules.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/widgets/ui.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_day.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_size.dart';
import 'package:lunasea/modules/dashboard/core/adapters/calendar_starting_type.dart';
import 'package:lunasea/modules/dashboard/core/dialogs.dart';
import 'package:lunasea/modules/settings/core/dialogs.dart';

class ConfigurationDashboardCalendarRoute extends StatefulWidget {
  const ConfigurationDashboardCalendarRoute({super.key});

  @override
  State<ConfigurationDashboardCalendarRoute> createState() => _State();
}

class _State extends State<ConfigurationDashboardCalendarRoute>
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
      title: 'settings.CalendarSettings'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        _futureDays(),
        _pastDays(),
        LunaDivider(),
        _startingDay(),
        _startingSize(),
        _startingView(),
        LunaDivider(),
        _modulesLidarr(),
        _modulesRadarr(),
        _modulesSonarr(),
      ],
    );
  }

  Widget _pastDays() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.PastDays'.tr(),
        body: [
          TextSpan(
            text: settings.dashboardCalendarPastDays == 1
                ? 'settings.DaysOne'.tr()
                : 'settings.DaysCount'.tr(
                    args: [settings.dashboardCalendarPastDays.toString()],
                  ),
          ),
        ],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          Tuple2<bool, int> result = await DashboardDialogs().setPastDays(
            context,
          );
          if (result.item1) {
            await context.read<SettingsStore>().setDashboardCalendarPastDays(
              result.item2,
            );
          }
        },
      ),
    );
  }

  Widget _futureDays() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.FutureDays'.tr(),
        body: [
          TextSpan(
            text: settings.dashboardCalendarFutureDays == 1
                ? 'settings.DaysOne'.tr()
                : 'settings.DaysCount'.tr(
                    args: [settings.dashboardCalendarFutureDays.toString()],
                  ),
          ),
        ],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          Tuple2<bool, int> result = await DashboardDialogs().setFutureDays(
            context,
          );
          if (result.item1) {
            await context.read<SettingsStore>().setDashboardCalendarFutureDays(
              result.item2,
            );
          }
        },
      ),
    );
  }

  Widget _modulesLidarr() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: LunaModule.LIDARR.title,
        body: [
          TextSpan(
            text: 'settings.ShowCalendarEntries'.tr(
              args: [LunaModule.LIDARR.title],
            ),
          ),
        ],
        trailing: LunaSwitch(
          value: settings.dashboardCalendarLidarrEnabled,
          onChanged: context
              .read<SettingsStore>()
              .setDashboardCalendarLidarrEnabled,
        ),
      ),
    );
  }

  Widget _modulesRadarr() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: LunaModule.RADARR.title,
        body: [
          TextSpan(
            text: 'settings.ShowCalendarEntries'.tr(
              args: [LunaModule.RADARR.title],
            ),
          ),
        ],
        trailing: LunaSwitch(
          value: settings.dashboardCalendarRadarrEnabled,
          onChanged: context
              .read<SettingsStore>()
              .setDashboardCalendarRadarrEnabled,
        ),
      ),
    );
  }

  Widget _modulesSonarr() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: LunaModule.SONARR.title,
        body: [
          TextSpan(
            text: 'settings.ShowCalendarEntries'.tr(
              args: [LunaModule.SONARR.title],
            ),
          ),
        ],
        trailing: LunaSwitch(
          value: settings.dashboardCalendarSonarrEnabled,
          onChanged: context
              .read<SettingsStore>()
              .setDashboardCalendarSonarrEnabled,
        ),
      ),
    );
  }

  Widget _startingView() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.StartingView'.tr(),
        body: [TextSpan(text: settings.dashboardCalendarStartingType.name)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          Tuple2<bool, CalendarStartingType?> _values = await SettingsDialogs()
              .editCalendarStartingView(context);
          if (_values.item1) {
            await context
                .read<SettingsStore>()
                .setDashboardCalendarStartingType(_values.item2!);
          }
        },
      ),
    );
  }

  Widget _startingDay() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.StartingDay'.tr(),
        body: [TextSpan(text: settings.dashboardCalendarStartingDay.name)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          Tuple2<bool, CalendarStartingDay?> results = await SettingsDialogs()
              .editCalendarStartingDay(context);
          if (results.item1) {
            await context.read<SettingsStore>().setDashboardCalendarStartingDay(
              results.item2!,
            );
          }
        },
      ),
    );
  }

  Widget _startingSize() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.StartingSize'.tr(),
        body: [TextSpan(text: settings.dashboardCalendarStartingSize.name)],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          Tuple2<bool, CalendarStartingSize?> _values = await SettingsDialogs()
              .editCalendarStartingSize(context);
          if (_values.item1) {
            await context
                .read<SettingsStore>()
                .setDashboardCalendarStartingSize(_values.item2!);
          }
        },
      ),
    );
  }
}
