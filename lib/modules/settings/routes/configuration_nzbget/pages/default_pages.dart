import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/nzbget.dart';

class ConfigurationNZBGetDefaultPagesRoute extends StatefulWidget {
  const ConfigurationNZBGetDefaultPagesRoute({super.key});

  @override
  State<ConfigurationNZBGetDefaultPagesRoute> createState() => _State();
}

class _State extends State<ConfigurationNZBGetDefaultPagesRoute>
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
    return LunaListView(controller: scrollController, children: [_homePage()]);
  }

  Widget _homePage() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'lunasea.Home'.tr(),
        body: [
          TextSpan(
            text: NZBGetNavigationBar.titles[settings.nzbgetDefaultPage],
          ),
        ],
        trailing: LunaIconButton(
          icon: NZBGetNavigationBar.icons[settings.nzbgetDefaultPage],
        ),
        onTap: () async {
          List values = await NZBGetDialogs.defaultPage(context);
          if (values[0]) settings.setNzbgetDefaultPage(values[1]);
        },
      ),
    );
  }
}
