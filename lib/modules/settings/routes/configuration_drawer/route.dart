import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

class ConfigurationDrawerRoute extends StatefulWidget {
  const ConfigurationDrawerRoute({super.key});

  @override
  State<ConfigurationDrawerRoute> createState() => _State();
}

class _State extends State<ConfigurationDrawerRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<LunaModule>? _modules;

  @override
  void initState() {
    super.initState();
    _modules = LunaDrawer.moduleOrderedList();
  }

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
      scrollControllers: [scrollController],
      title: 'settings.Drawer'.tr(),
    );
  }

  Widget _body() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => Column(
        children: [
          SizedBox(height: LunaUI.MARGIN_H_DEFAULT_V_HALF.bottom),
          LunaBlock(
            title: 'settings.AutomaticallyManageOrder'.tr(),
            body: [
              TextSpan(
                text: 'settings.AutomaticallyManageOrderDescription'.tr(),
              ),
            ],
            trailing: LunaSwitch(
              value: settings.drawerAutomaticManage,
              onChanged: settings.setDrawerAutomaticManage,
            ),
          ),
          LunaDivider(),
          Expanded(
            child: LunaReorderableListViewBuilder(
              padding: MediaQuery.of(context).padding
                  .copyWith(top: 0)
                  .add(
                    EdgeInsets.only(
                      bottom: LunaUI.MARGIN_H_DEFAULT_V_HALF.bottom,
                    ),
                  ),
              controller: scrollController,
              itemCount: _modules!.length,
              itemBuilder: (context, index) =>
                  _reorderableModuleTile(index, settings.drawerAutomaticManage),
              onReorder: (oIndex, nIndex) {
                if (oIndex > _modules!.length) oIndex = _modules!.length;
                if (oIndex < nIndex) nIndex--;
                LunaModule module = _modules![oIndex];
                _modules!.remove(module);
                _modules!.insert(nIndex, module);
                settings.setDrawerManualOrder(_modules!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _reorderableModuleTile(int index, bool automaticManage) {
    return LunaBlock(
      key: ObjectKey(_modules![index]),
      disabled: automaticManage,
      title: _modules![index].title,
      body: [TextSpan(text: _modules![index].description)],
      leading: LunaIconButton(icon: _modules![index].icon),
      trailing: automaticManage
          ? null
          : LunaReorderableListViewDragger(index: index),
    );
  }
}
