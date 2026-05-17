import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/router/routes/settings.dart';

class InstanceNotConfiguredPage extends StatelessWidget {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final LunaModule module;
  final String instanceId;

  InstanceNotConfiguredPage({
    super.key,
    required this.module,
    required this.instanceId,
  });

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<ProfilesStore>();
    final instances = profiles.instancesFor(profiles.activeProfile, module);
    final instance = instances.where((i) => i.id == instanceId).firstOrNull;
    final displayName = instance?.displayName ?? instanceId;

    String message;
    if (instance == null) {
      message = '"$displayName" has not been configured yet. Add and configure it in settings.';
    } else if (!instance.enabled) {
      message = '"$displayName" is disabled. Configure its connection details and test the connection to enable it.';
    } else {
      message = '"$displayName" has no host configured. Set its connection details in settings.';
    }

    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: LunaAppBar(title: module.title),
      body: LunaMessage(
        text: message,
        buttonText: 'lunasea.GoToSettings'.tr(),
        onTap: () => SettingsRoutes.CONFIGURATION_SERVICE_INSTANCE_CONNECTION.go(
          params: {'service': module.key, 'instanceId': instanceId},
        ),
      ),
    );
  }
}
