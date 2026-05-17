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
        if (!profiles.isEnabled(module)) return [const SizedBox(height: 0.0)];
        if (!module.supportsServiceInstances) {
          return [_buildEntry(context: context, module: module)];
        }

        final instances = profiles.enabledInstances(
          profiles.activeProfile,
          module,
        );
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
  }) {
    return _buildEntry(
      context: context,
      module: module,
      label: '${module.title} - ${instance.displayName}',
      current:
          page == module.key.toLowerCase() &&
          currentInstanceId(module) == instance.id,
      onTap: () async {
        Navigator.of(context).pop();
        module.launchInstance(instance);
      },
    );
  }

  Widget _buildEntry({
    required BuildContext context,
    required LunaModule module,
    String? label,
    bool? current,
    void Function()? onTap,
  }) {
    bool currentPage = current ?? page == module.key.toLowerCase();
    return SizedBox(
      height: LunaTextInputBar.defaultAppBarHeight,
      child: InkWell(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              child: Icon(
                module.icon,
                color: currentPage ? module.color : LunaColours.white,
              ),
              padding: LunaUI.MARGIN_DEFAULT_HORIZONTAL * 1.5,
            ),
            Expanded(
              child: Text(
                label ?? module.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: currentPage ? module.color : LunaColours.white,
                  fontWeight: LunaUI.FONT_WEIGHT_BOLD,
                ),
              ),
            ),
          ],
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
