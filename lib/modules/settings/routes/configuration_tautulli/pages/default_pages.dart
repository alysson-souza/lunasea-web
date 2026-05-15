import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tautulli.dart';

class ConfigurationTautulliDefaultPagesRoute extends StatefulWidget {
  const ConfigurationTautulliDefaultPagesRoute({
    Key? key,
  }) : super(key: key);

  @override
  State<ConfigurationTautulliDefaultPagesRoute> createState() => _State();
}

class _State extends State<ConfigurationTautulliDefaultPagesRoute>
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
      title: 'settings.DefaultPages'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        _homePage(),
        _graphsPage(),
        _libraryDetailsPage(),
        _mediaDetailsPage(),
        _userDetailsPage(),
      ],
    );
  }

  Widget _homePage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'lunasea.Home'.tr(),
        body: [
          TextSpan(
            text: TautulliNavigationBar.titles[settings.tautulliDefaultPage],
          )
        ],
        trailing: LunaIconButton(
          icon: TautulliNavigationBar.icons[settings.tautulliDefaultPage],
        ),
        onTap: () async {
          List values = await TautulliDialogs.setDefaultPage(
            context,
            titles: TautulliNavigationBar.titles,
            icons: TautulliNavigationBar.icons,
          );
          if (values[0]) settings.setTautulliDefaultPage(values[1]);
        },
      ),
    );
  }

  Widget _graphsPage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'tautulli.Graphs'.tr(),
        body: [
          TextSpan(
            text: TautulliGraphsNavigationBar
                .titles[settings.tautulliGraphsDefaultPage],
          )
        ],
        trailing: LunaIconButton(
          icon: TautulliGraphsNavigationBar
              .icons[settings.tautulliGraphsDefaultPage],
        ),
        onTap: () async {
          List values = await TautulliDialogs.setDefaultPage(
            context,
            titles: TautulliGraphsNavigationBar.titles,
            icons: TautulliGraphsNavigationBar.icons,
          );
          if (values[0]) settings.setTautulliGraphsDefaultPage(values[1]);
        },
      ),
    );
  }

  Widget _libraryDetailsPage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'tautulli.LibraryDetails'.tr(),
        body: [
          TextSpan(
            text: TautulliLibrariesDetailsNavigationBar
                .titles[settings.tautulliLibraryDetailsDefaultPage],
          )
        ],
        trailing: LunaIconButton(
          icon: TautulliLibrariesDetailsNavigationBar
              .icons[settings.tautulliLibraryDetailsDefaultPage],
        ),
        onTap: () async {
          List values = await TautulliDialogs.setDefaultPage(
            context,
            titles: TautulliLibrariesDetailsNavigationBar.titles,
            icons: TautulliLibrariesDetailsNavigationBar.icons,
          );
          if (values[0]) {
            settings.setTautulliLibraryDetailsDefaultPage(values[1]);
          }
        },
      ),
    );
  }

  Widget _mediaDetailsPage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'tautulli.MediaDetails'.tr(),
        body: [
          TextSpan(
            text: TautulliMediaDetailsNavigationBar
                .titles[settings.tautulliMediaDetailsDefaultPage],
          ),
        ],
        trailing: LunaIconButton(
          icon: TautulliMediaDetailsNavigationBar
              .icons[settings.tautulliMediaDetailsDefaultPage],
        ),
        onTap: () async {
          List values = await TautulliDialogs.setDefaultPage(
            context,
            titles: TautulliMediaDetailsNavigationBar.titles,
            icons: TautulliMediaDetailsNavigationBar.icons,
          );
          if (values[0]) {
            settings.setTautulliMediaDetailsDefaultPage(values[1]);
          }
        },
      ),
    );
  }

  Widget _userDetailsPage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'tautulli.UserDetails'.tr(),
        body: [
          TextSpan(
            text: TautulliUserDetailsNavigationBar
                .titles[settings.tautulliUserDetailsDefaultPage],
          ),
        ],
        trailing: LunaIconButton(
          icon: TautulliUserDetailsNavigationBar
              .icons[settings.tautulliUserDetailsDefaultPage],
        ),
        onTap: () async {
          List values = await TautulliDialogs.setDefaultPage(
            context,
            titles: TautulliUserDetailsNavigationBar.titles,
            icons: TautulliUserDetailsNavigationBar.icons,
          );
          if (values[0]) settings.setTautulliUserDetailsDefaultPage(values[1]);
        },
      ),
    );
  }
}
