import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/system/backend_state.dart';

class ServiceInstancesRoute extends StatefulWidget {
  final LunaModule module;

  const ServiceInstancesRoute({super.key, required this.module});

  @override
  State<ServiceInstancesRoute> createState() => _State();
}

class _State extends State<ServiceInstancesRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar(),
      body: _body(),
      bottomNavigationBar: _bottomActionBar(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar(
      title: '${widget.module.title} Service Instances',
      scrollControllers: [scrollController],
    );
  }

  Widget _bottomActionBar() {
    return LunaBottomActionBar(
      actions: [
        LunaButton.text(
          text: 'Add Instance',
          icon: Icons.add_rounded,
          onTap: _addInstance,
        ),
      ],
    );
  }

  Widget _body() {
    return Consumer<ProfilesStore>(
      builder: (context, profiles, _) {
        final activeProfile = profiles.activeProfile;
        final instances = profiles.instancesFor(activeProfile, widget.module);
        return LunaListView(
          controller: scrollController,
          children: [
            if (instances.isEmpty)
              LunaBlock(
                title: 'No Instances',
                body: [
                  TextSpan(
                    text:
                        'Add a ${widget.module.title} instance to configure it.',
                  ),
                ],
              )
            else
              ...instances.map(_instanceBlock),
          ],
        );
      },
    );
  }

  Widget _instanceBlock(LunaServiceInstance instance) {
    return LunaBlock(
      title: '${widget.module.title} - ${instance.displayName}',
      body: [TextSpan(text: instance.enabled ? 'Enabled' : 'Disabled')],
      trailing: LunaSwitch(
        value: instance.enabled,
        onChanged: (value) async {
          final saved = await SettingsServiceInstanceSettings.save(
            _copy(instance, enabled: value),
          );
          _upsert(saved);
        },
      ),
      onTap: () => SettingsRoutes.CONFIGURATION_SERVICE_INSTANCE_CONNECTION.go(
        params: {'service': widget.module.key, 'instanceId': instance.id},
      ),
    );
  }

  Future<void> _addInstance() async {
    final profiles = context.read<ProfilesStore>();
    final draft = SettingsServiceInstanceSettings.newDraft(
      profiles.activeProfile,
      widget.module,
      profiles.instancesFor(profiles.activeProfile, widget.module),
    );
    final created = await SettingsServiceInstanceSettings.create(draft);
    _upsert(created);
  }

  void _upsert(LunaServiceInstance instance) {
    final profile = LunaBackendState.profiles[instance.profileId];
    if (profile == null) return;
    profile.serviceInstances.removeWhere((item) => item.key == instance.key);
    profile.serviceInstances.add(instance);
    context.read<ProfilesStore>().refresh();
  }

  LunaServiceInstance _copy(LunaServiceInstance instance, {bool? enabled}) {
    return LunaServiceInstance.fromJson({
      ...instance.toJson(),
      if (enabled != null) 'enabled': enabled,
    });
  }
}
