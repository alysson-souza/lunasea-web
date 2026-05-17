import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

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
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: LunaAppBar(title: module.title),
      body: LunaMessage(
        text: 'Instance "$instanceId" is not configured.',
        buttonText: 'lunasea.GoToSettings'.tr(),
        onTap: module.settingsRoute?.go,
      ),
    );
  }
}
