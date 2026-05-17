import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';

class ConfigurationSonarrDefaultPagesRoute extends StatefulWidget {
  const ConfigurationSonarrDefaultPagesRoute({super.key});

  @override
  State<ConfigurationSonarrDefaultPagesRoute> createState() => _State();
}

class _State extends State<ConfigurationSonarrDefaultPagesRoute>
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
      title: 'settings.DefaultPages'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [_homePage(), _seriesDetailsPage(), _seasonDetailsPage()],
    );
  }

  Widget _homePage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) {
        return LunaBlock(
          title: 'lunasea.Home'.tr(),
          body: [
            TextSpan(
              text: SonarrNavigationBar.titles[settings.sonarrDefaultPage],
            ),
          ],
          trailing: LunaIconButton(
            icon: SonarrNavigationBar.icons[settings.sonarrDefaultPage],
          ),
          onTap: () async {
            List values = await SonarrDialogs.setDefaultPage(
              context,
              titles: SonarrNavigationBar.titles,
              icons: SonarrNavigationBar.icons,
            );
            if (values[0]) settings.setSonarrDefaultPage(values[1]);
          },
        );
      },
    );
  }

  Widget _seriesDetailsPage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) {
        return LunaBlock(
          title: 'sonarr.SeriesDetails'.tr(),
          body: [
            TextSpan(
              text: SonarrSeriesDetailsNavigationBar
                  .titles[settings.sonarrSeriesDetailsDefaultPage],
            ),
          ],
          trailing: LunaIconButton(
            icon: SonarrSeriesDetailsNavigationBar
                .icons[settings.sonarrSeriesDetailsDefaultPage],
          ),
          onTap: () async {
            List values = await SonarrDialogs.setDefaultPage(
              context,
              titles: SonarrSeriesDetailsNavigationBar.titles,
              icons: SonarrSeriesDetailsNavigationBar.icons,
            );
            if (values[0]) {
              settings.setSonarrSeriesDetailsDefaultPage(values[1]);
            }
          },
        );
      },
    );
  }

  Widget _seasonDetailsPage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) {
        return LunaBlock(
          title: 'sonarr.SeasonDetails'.tr(),
          body: [
            TextSpan(
              text: SonarrSeasonDetailsNavigationBar
                  .titles[settings.sonarrSeasonDetailsDefaultPage],
            ),
          ],
          trailing: LunaIconButton(
            icon: SonarrSeasonDetailsNavigationBar
                .icons[settings.sonarrSeasonDetailsDefaultPage],
          ),
          onTap: () async {
            List values = await SonarrDialogs.setDefaultPage(
              context,
              titles: SonarrSeasonDetailsNavigationBar.titles,
              icons: SonarrSeasonDetailsNavigationBar.icons,
            );
            if (values[0]) {
              settings.setSonarrSeasonDetailsDefaultPage(values[1]);
            }
          },
        );
      },
    );
  }
}
