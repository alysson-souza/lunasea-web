import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/utils/profile_tools.dart';

class ProfilesRoute extends StatefulWidget {
  const ProfilesRoute({super.key});

  @override
  State<ProfilesRoute> createState() => _State();
}

class _State extends State<ProfilesRoute> with LunaScrollControllerMixin {
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
      title: 'settings.Profiles'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return Consumer<ProfilesStore>(
      builder: (context, profiles, _) => LunaListView(
        controller: scrollController,
        children: [
          SettingsBanners.PROFILES_SUPPORT.banner(),
          _enabledProfile(profiles),
          _addProfile(profiles),
          _renameProfile(profiles),
          _deleteProfile(profiles),
        ],
      ),
    );
  }

  Widget _addProfile(ProfilesStore store) {
    return LunaBlock(
      title: 'settings.AddProfile'.tr(),
      body: [TextSpan(text: 'settings.AddProfileDescription'.tr())],
      trailing: const LunaIconButton(icon: LunaIcons.ADD),
      onTap: () async {
        final dialogs = SettingsDialogs();
        final context = LunaState.context;
        final profiles = store.profiles;

        final selected = await dialogs.addProfile(context, profiles);
        if (selected.item1) {
          await LunaProfileTools(store).create(selected.item2);
        }
      },
    );
  }

  Widget _renameProfile(ProfilesStore store) {
    return LunaBlock(
      title: 'settings.RenameProfile'.tr(),
      body: [TextSpan(text: 'settings.RenameProfileDescription'.tr())],
      trailing: const LunaIconButton(icon: LunaIcons.RENAME),
      onTap: () async {
        final dialogs = SettingsDialogs();
        final context = LunaState.context;
        final profiles = store.profiles;

        final selected = await dialogs.renameProfile(context, profiles);
        if (selected.item1) {
          final name = await dialogs.renameProfileSelected(context, profiles);
          if (name.item1) {
            await LunaProfileTools(store).rename(selected.item2, name.item2);
          }
        }
      },
    );
  }

  Widget _deleteProfile(ProfilesStore store) {
    return LunaBlock(
      title: 'settings.DeleteProfile'.tr(),
      body: [TextSpan(text: 'settings.DeleteProfileDescription'.tr())],
      trailing: const LunaIconButton(icon: LunaIcons.DELETE),
      onTap: () async {
        final dialogs = SettingsDialogs();
        final context = LunaState.context;
        final profiles = store.profiles;
        profiles.removeWhere((p) => p == store.activeProfile);

        if (profiles.isEmpty) {
          showLunaInfoSnackBar(
            title: 'settings.NoProfilesFound'.tr(),
            message: 'settings.NoAdditionalProfilesAdded'.tr(),
          );
          return;
        }

        final selected = await dialogs.deleteProfile(context, profiles);
        if (selected.item1) {
          await LunaProfileTools(store).remove(selected.item2);
        }
      },
    );
  }

  Widget _enabledProfile(ProfilesStore store) {
    return LunaBlock(
      title: 'settings.EnabledProfile'.tr(),
      body: [TextSpan(text: store.activeProfile)],
      trailing: const LunaIconButton(icon: LunaIcons.USER),
      onTap: () async {
        final dialogs = SettingsDialogs();
        final context = LunaState.context;
        final profiles = store.profiles;
        profiles.removeWhere((p) => p == store.activeProfile);

        if (profiles.isEmpty) {
          showLunaInfoSnackBar(
            title: 'settings.NoProfilesFound'.tr(),
            message: 'settings.NoAdditionalProfilesAdded'.tr(),
          );
          return;
        }

        final selected = await dialogs.enabledProfile(context, profiles);
        if (selected.item1) {
          await LunaProfileTools(store).changeTo(selected.item2);
        }
      },
    );
  }
}
