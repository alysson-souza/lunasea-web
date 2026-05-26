import 'package:flutter/material.dart';

import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/system/filesystem/filesystem.dart';
import 'package:lunasea/system/gateway/gateway.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';

class ConfigImportExportRoute extends StatefulWidget {
  const ConfigImportExportRoute({super.key});

  @override
  State<ConfigImportExportRoute> createState() => _State();
}

class _State extends State<ConfigImportExportRoute>
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
      title: 'settings.ImportExportConfiguration'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        LunaBlock(
          title: 'settings.ExportConfiguration'.tr(),
          body: [
            TextSpan(text: 'settings.ExportConfigurationDescription'.tr()),
          ],
          trailing: const LunaIconButton(icon: Icons.file_download_rounded),
          onTap: _exportConfiguration,
        ),
        LunaBlock(
          title: 'settings.ImportConfiguration'.tr(),
          body: [
            TextSpan(text: 'settings.ImportConfigurationDescription'.tr()),
          ],
          trailing: const LunaIconButton(icon: Icons.file_upload_rounded),
          onTap: _importConfiguration,
        ),
      ],
    );
  }

  Future<void> _exportConfiguration() async {
    if (!LunaFileSystem.isSupported) {
      showLunaErrorSnackBar(title: 'settings.NotAvailable'.tr());
      return;
    }
    final confirmed = await SettingsDialogs().exportConfiguration(context);
    if (!confirmed) return;

    try {
      final data = await LunaGateway.exportConfiguration();
      final saved = await LunaFileSystem().save(
        context,
        'lunasea-web-config.json',
        data,
      );
      if (!saved) return;
      showLunaSuccessSnackBar(
        title: 'settings.ConfigurationExported'.tr(),
        message: 'settings.ConfigurationExportedDescription'.tr(),
      );
    } catch (error) {
      showLunaErrorSnackBar(
        title: 'settings.ConfigurationExportFailed'.tr(),
        error: error,
      );
    }
  }

  Future<void> _importConfiguration() async {
    if (!LunaFileSystem.isSupported) {
      showLunaErrorSnackBar(title: 'settings.NotAvailable'.tr());
      return;
    }

    try {
      final file = await LunaFileSystem().read(context, ['json', 'xml']);
      if (file == null) return;

      final confirmed = await SettingsDialogs().importConfiguration(
        context,
        file.name,
      );
      if (!confirmed) return;

      final state = await LunaGateway.importConfiguration(file.data);
      await LunaBackendState.hydrate(state);
      _refreshBackendStores();
      LunaState.reset(context);
      showLunaSuccessSnackBar(
        title: 'settings.ConfigurationImported'.tr(),
        message: 'settings.ConfigurationImportedDescription'.tr(),
      );
    } catch (error) {
      showLunaErrorSnackBar(
        title: 'settings.ConfigurationImportFailed'.tr(),
        error: error,
      );
    }
  }

  void _refreshBackendStores() {
    context.read<ProfilesStore>().refresh();
    context.read<SettingsStore>().refresh();
    context.read<IndexersStore>().refresh();
    context.read<ExternalModulesStore>().refresh();
    context.read<DismissedBannersStore>().refresh();
    context.read<LogsStore>().refresh();
  }
}
