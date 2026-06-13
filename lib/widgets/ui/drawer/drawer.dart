import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/router/routes.dart';

class LunaDrawer extends StatelessWidget {
  final String page;

  const LunaDrawer({super.key, required this.page});

  static List<LunaModule> moduleAlphabeticalList() {
    return LunaModule.active
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  static List<LunaModule> moduleOrderedList() {
    try {
      const db = LunaSeaPreferences.DRAWER_MANUAL_ORDER;
      final modules = List.from(db.read());
      final missing = LunaModule.active;

      missing.retainWhere((m) => !modules.contains(m));
      modules.addAll(missing);
      modules.retainWhere((m) => (m as LunaModule).featureFlag);

      return modules.cast<LunaModule>();
    } catch (error, stack) {
      LunaLogger().error('Failed to create ordered module list', error, stack);
      return moduleAlphabeticalList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      ProfilesStore,
      IndexersStore,
      ExternalModulesStore,
      SettingsStore
    >(
      builder: (context, profiles, _, __, settings, ___) {
        return Drawer(
          elevation: LunaUI.ELEVATION,
          backgroundColor: Theme.of(context).primaryColor,
          child: Column(
            children: [
              LunaDrawerHeader(page: page),
              Expanded(
                child: LunaListView(
                  controller: PrimaryScrollController.of(context),
                  children: _moduleList(
                    context,
                    profiles,
                    settings.drawerAutomaticManage
                        ? moduleAlphabeticalList()
                        : moduleOrderedList(),
                  ),
                  physics: const ClampingScrollPhysics(),
                  padding: MediaQuery.of(context).padding.copyWith(top: 0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _sharedHeader(BuildContext context) {
    return [_buildEntry(context: context, module: LunaModule.DASHBOARD)];
  }

  List<Widget> _moduleList(
    BuildContext context,
    ProfilesStore profiles,
    List<LunaModule> modules,
  ) {
    return <Widget>[
      ..._sharedHeader(context),
      ...modules.expand((module) {
        if (!profiles.isEnabled(module)) return const <Widget>[];
        if (!module.supportsServiceInstances) {
          return [_buildEntry(context: context, module: module)];
        }

        final instances = profiles.enabledInstances(
          profiles.activeProfile,
          module,
        );
        if (module.supportsConsolidatedView) {
          return [
            _buildConsolidatedEntry(context: context, module: module),
            ...instances.map(
              (instance) => _buildInstanceEntry(
                context: context,
                module: module,
                instance: instance,
                nested: true,
              ),
            ),
          ];
        }

        return instances.map(
          (instance) => _buildInstanceEntry(
            context: context,
            module: module,
            instance: instance,
          ),
        );
      }),
    ];
  }

  Widget _buildInstanceEntry({
    required BuildContext context,
    required LunaModule module,
    required LunaServiceInstance instance,
    bool nested = false,
  }) {
    return _buildEntry(
      context: context,
      module: module,
      label: nested
          ? instance.displayName
          : '${module.title} - ${instance.displayName}',
      current:
          page == module.key.toLowerCase() &&
          currentInstanceId(module) == instance.id,
      nested: nested,
      icon: nested ? Icons.dns_rounded : null,
      onTap: () async {
        Navigator.of(context).pop();
        module.launchInstance(instance);
      },
    );
  }

  Widget _buildConsolidatedEntry({
    required BuildContext context,
    required LunaModule module,
  }) {
    return _buildEntry(
      context: context,
      module: module,
      current:
          page == module.key.toLowerCase() && currentInstanceId(module) == null,
    );
  }

  Widget _buildEntry({
    required BuildContext context,
    required LunaModule module,
    String? label,
    bool? current,
    void Function()? onTap,
    bool nested = false,
    IconData? icon,
  }) {
    bool currentPage = current ?? page == module.key.toLowerCase();
    final contentColor = currentPage
        ? module.color
        : nested
        ? LunaColours.white70
        : LunaColours.white;
    return SizedBox(
      height: nested
          ? LunaTextInputBar.defaultAppBarHeight * 0.85
          : LunaTextInputBar.defaultAppBarHeight,
      child: InkWell(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: currentPage
                ? module.color.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4.0,
                color: currentPage ? module.color : Colors.transparent,
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: nested
                      ? LunaUI.DEFAULT_MARGIN_SIZE * 2.5
                      : LunaUI.DEFAULT_MARGIN_SIZE * 1.5,
                  right: LunaUI.DEFAULT_MARGIN_SIZE * 1.5,
                ),
                child: Icon(
                  icon ?? module.icon,
                  color: contentColor,
                  size: nested ? 20.0 : LunaUI.ICON_SIZE,
                ),
              ),
              Expanded(
                child: Text(
                  label ?? module.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: nested
                        ? LunaUI.FONT_SIZE_H3
                        : LunaUI.FONT_SIZE_H2,
                    fontWeight: currentPage || !nested
                        ? LunaUI.FONT_WEIGHT_BOLD
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        onTap:
            onTap ??
            () async {
              Navigator.of(context).pop();
              if (!currentPage) module.launch();
            },
      ),
    );
  }
}
