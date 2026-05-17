import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/system/backend_state.dart';
import 'package:lunasea/widgets/pages/instance_not_configured.dart';

class ServiceInstanceConnectionDetailsRoute extends StatefulWidget {
  final LunaModule module;
  final String instanceId;

  const ServiceInstanceConnectionDetailsRoute({
    super.key,
    required this.module,
    required this.instanceId,
  });

  @override
  State<ServiceInstanceConnectionDetailsRoute> createState() => _State();
}

class _State extends State<ServiceInstanceConnectionDetailsRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final instance = _instance(context);
    if (instance == null) {
      return InstanceNotConfiguredPage(
        module: widget.module,
        instanceId: widget.instanceId,
      );
    }
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar(instance),
      body: _body(instance),
      bottomNavigationBar: _bottomActionBar(instance),
    );
  }

  PreferredSizeWidget _appBar(LunaServiceInstance instance) {
    return LunaAppBar(
      title: instance.displayName,
      scrollControllers: [scrollController],
    );
  }

  Widget _bottomActionBar(LunaServiceInstance instance) {
    return LunaBottomActionBar(
      actions: [
        LunaButton.text(
          text: 'settings.TestConnection'.tr(),
          icon: LunaIcons.CONNECTION_TEST,
          onTap: () => _test(instance),
        ),
      ],
    );
  }

  Widget _body(LunaServiceInstance instance) {
    return LunaListView(
      controller: scrollController,
      children: [
        _displayName(instance),
        _host(instance),
        if (widget.module == LunaModule.NZBGET) ...[
          _username(instance),
          _password(instance),
        ] else
          _apiKey(instance),
        LunaDivider(),
        _delete(instance),
      ],
    );
  }

  Widget _displayName(LunaServiceInstance instance) {
    return LunaBlock(
      title: 'Display Name',
      body: [TextSpan(text: instance.displayName)],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        final values = await LunaDialogs().editText(
          context,
          'Display Name',
          prefill: instance.displayName,
        );
        if (values.item1) {
          await _save(_copy(instance, displayName: values.item2));
        }
      },
    );
  }

  Widget _host(LunaServiceInstance instance) {
    return LunaBlock(
      title: 'settings.Host'.tr(),
      body: [
        TextSpan(
          text: instance.host.isEmpty ? 'lunasea.NotSet'.tr() : instance.host,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        final values = await SettingsDialogs().editHost(
          context,
          prefill: instance.host,
        );
        if (values.item1) await _save(_copy(instance, host: values.item2));
      },
    );
  }

  Widget _apiKey(LunaServiceInstance instance) {
    return LunaBlock(
      title: 'settings.ApiKey'.tr(),
      body: [
        TextSpan(
          text: !instance.hasApiKey
              ? 'lunasea.NotSet'.tr()
              : LunaUI.TEXT_OBFUSCATED_PASSWORD,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        final values = await LunaDialogs().editText(
          context,
          'settings.ApiKey'.tr(),
          prefill: instance.apiKey,
        );
        if (values.item1) await _save(_copy(instance, apiKey: values.item2));
      },
    );
  }

  Widget _username(LunaServiceInstance instance) {
    return LunaBlock(
      title: 'settings.Username'.tr(),
      body: [
        TextSpan(
          text: !instance.hasUsername
              ? 'lunasea.NotSet'.tr()
              : instance.username.isEmpty
              ? LunaUI.TEXT_OBFUSCATED_PASSWORD
              : instance.username,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        final values = await LunaDialogs().editText(
          context,
          'settings.Username'.tr(),
          prefill: instance.username,
        );
        if (values.item1) await _save(_copy(instance, username: values.item2));
      },
    );
  }

  Widget _password(LunaServiceInstance instance) {
    return LunaBlock(
      title: 'settings.Password'.tr(),
      body: [
        TextSpan(
          text: !instance.hasPassword
              ? 'lunasea.NotSet'.tr()
              : LunaUI.TEXT_OBFUSCATED_PASSWORD,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        final values = await LunaDialogs().editText(
          context,
          'settings.Password'.tr(),
          prefill: instance.password,
        );
        if (values.item1) await _save(_copy(instance, password: values.item2));
      },
    );
  }

  Widget _delete(LunaServiceInstance instance) {
    return LunaBlock(
      title: 'Delete Instance',
      titleColor: LunaColours.red,
      body: [TextSpan(text: 'Delete ${instance.displayName}.')],
      trailing: const LunaIconButton(
        icon: Icons.delete_rounded,
        color: LunaColours.red,
      ),
      onTap: () async {
        await SettingsServiceInstanceSettings.delete(instance);
        _remove(instance);
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  LunaServiceInstance? _instance(BuildContext context) {
    final profiles = context.watch<ProfilesStore>();
    final profile = profiles.activeProfile;
    for (final instance in profiles.instancesFor(profile, widget.module)) {
      if (instance.id == widget.instanceId) return instance;
    }
    return null;
  }

  Future<void> _save(LunaServiceInstance instance) async {
    final saved = await SettingsServiceInstanceSettings.save(instance);
    _upsert(saved);
  }

  Future<void> _test(LunaServiceInstance instance) async {
    await SettingsServiceInstanceSettings.test(instance)
        .then(
          (_) => showLunaSuccessSnackBar(
            title: 'settings.ConnectedSuccessfully'.tr(),
            message: 'settings.ConnectedSuccessfullyMessage'.tr(
              args: [widget.module.title],
            ),
          ),
        )
        .catchError((error, trace) {
          LunaLogger().error('Connection Test Failed', error, trace);
          showLunaErrorSnackBar(
            title: 'settings.ConnectionTestFailed'.tr(),
            error: error,
          );
        });
  }

  void _upsert(LunaServiceInstance instance) {
    final profile = LunaBackendState.profiles[instance.profileId];
    if (profile == null) return;
    profile.serviceInstances.removeWhere((item) => item.key == instance.key);
    profile.serviceInstances.add(instance);
    context.read<ProfilesStore>().refresh();
  }

  void _remove(LunaServiceInstance instance) {
    final profile = LunaBackendState.profiles[instance.profileId];
    if (profile == null) return;
    profile.serviceInstances.removeWhere((item) => item.key == instance.key);
    context.read<ProfilesStore>().refresh();
  }

  LunaServiceInstance _copy(
    LunaServiceInstance instance, {
    String? displayName,
    String? host,
    String? apiKey,
    String? username,
    String? password,
  }) {
    return LunaServiceInstance.fromJson({
      ...instance.toJson(),
      if (displayName != null) 'displayName': displayName,
      if (host != null) 'upstreamUrl': host,
      if (apiKey != null) 'apiKey': apiKey,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
    });
  }
}
