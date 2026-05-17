import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

import 'package:lunasea/modules/dashboard/core/dialogs.dart';
import 'package:lunasea/modules/dashboard/routes/dashboard/widgets/navigation_bar.dart';

class ConfigurationDashboardDefaultPagesRoute extends StatefulWidget {
  const ConfigurationDashboardDefaultPagesRoute({super.key});

  @override
  State<ConfigurationDashboardDefaultPagesRoute> createState() => _State();
}

class _State extends State<ConfigurationDashboardDefaultPagesRoute>
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
            text: HomeNavigationBar.titles[settings.dashboardDefaultPage],
          ),
        ],
        trailing: LunaIconButton(
          icon: HomeNavigationBar.icons[settings.dashboardDefaultPage],
        ),
        onTap: () async {
          final values = await DashboardDialogs().defaultPage(context);
          if (values.item1) {
            await context.read<SettingsStore>().setDashboardDefaultPage(
              values.item2,
            );
          }
        },
      ),
    );
  }
}
