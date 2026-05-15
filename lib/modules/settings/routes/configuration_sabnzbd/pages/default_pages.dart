import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd.dart';

class ConfigurationSABnzbdDefaultPagesRoute extends StatefulWidget {
  const ConfigurationSABnzbdDefaultPagesRoute({
    Key? key,
  }) : super(key: key);

  @override
  State<ConfigurationSABnzbdDefaultPagesRoute> createState() => _State();
}

class _State extends State<ConfigurationSABnzbdDefaultPagesRoute>
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
      ],
    );
  }

  Widget _homePage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'lunasea.Home'.tr(),
        body: [
          TextSpan(
            text: SABnzbdNavigationBar.titles[settings.sabnzbdDefaultPage],
          )
        ],
        trailing: LunaIconButton(
          icon: SABnzbdNavigationBar.icons[settings.sabnzbdDefaultPage],
        ),
        onTap: () async {
          List values = await SABnzbdDialogs.defaultPage(context);
          if (values[0]) settings.setSabnzbdDefaultPage(values[1]);
        },
      ),
    );
  }
}
