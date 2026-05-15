import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings/core/dialogs.dart';
import 'package:lunasea/system/gateway/connection_mode.dart';
import 'package:lunasea/system/gateway/gateway.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class SettingsServiceConnection {
  SettingsServiceConnection._();

  static bool get gatewayAvailable => LunaGateway.available;

  static bool isGatewayConfigured(BuildContext context, LunaModule module) =>
      context.watch<ProfilesStore>().active.connectionMode(module) ==
      LunaConnectionMode.gateway;

  static Widget gatewayBlock({
    required BuildContext context,
    required LunaModule module,
    required VoidCallback onChanged,
  }) {
    final profile = context.watch<ProfilesStore>().active;
    final gatewayProfile = _gatewayProfile(profile, module);
    final cached = LunaGateway.serviceConnection(
      module: module,
      profile: gatewayProfile,
    );
    return FutureBuilder<Map<String, dynamic>?>(
      initialData: cached,
      future: _findGatewayService(module, gatewayProfile),
      builder: (context, snapshot) {
        final service = snapshot.data;
        final upstream = service?['upstreamUrl']?.toString() ?? '';
        return Column(
          children: [
            LunaBlock(
              title: 'settings.UpstreamURL'.tr(),
              body: [
                TextSpan(
                  text: upstream.isEmpty ? 'lunasea.NotSet'.tr() : upstream,
                ),
              ],
              trailing: const LunaIconButton.arrow(),
              onTap: () => _configureGatewayUpstream(
                context: context,
                module: module,
                onChanged: onChanged,
              ),
            ),
            if (module == LunaModule.NZBGET)
              LunaBlock(
                title: 'settings.BasicAuthentication'.tr(),
                body: [
                  TextSpan(
                    text: _hasCompleteCredential(module, service)
                        ? LunaUI.TEXT_OBFUSCATED_PASSWORD
                        : 'lunasea.NotSet'.tr(),
                  ),
                ],
                trailing: const LunaIconButton.arrow(),
                onTap: () => _configureGatewayCredentials(
                  context: context,
                  module: module,
                  onChanged: onChanged,
                ),
              )
            else
              LunaBlock(
                title: 'settings.ApiKey'.tr(),
                body: [
                  TextSpan(
                    text: _hasCompleteCredential(module, service)
                        ? LunaUI.TEXT_OBFUSCATED_PASSWORD
                        : 'lunasea.NotSet'.tr(),
                  ),
                ],
                trailing: const LunaIconButton.arrow(),
                onTap: () => _configureGatewayApiKey(
                  context: context,
                  module: module,
                  onChanged: onChanged,
                ),
              ),
          ],
        );
      },
    );
  }

  static Widget deleteGatewayBlock({
    required BuildContext context,
    required LunaModule module,
    required VoidCallback onChanged,
  }) {
    return LunaBlock(
      title: 'settings.DeleteGatewayConnection'.tr(),
      titleColor: LunaColours.red,
      body: [
        TextSpan(text: 'settings.DeleteGatewayConnectionDescription'.tr()),
      ],
      trailing: const LunaIconButton(
        icon: Icons.delete_rounded,
        color: LunaColours.red,
      ),
      onTap: () async {
        final result = await SettingsDialogs().deleteGatewayConnection(context);
        if (!result) return;
        final store = context.read<ProfilesStore>();
        final profile = LunaProfile.clone(store.active);
        final gatewayProfile = _gatewayProfile(profile, module);
        try {
          await LunaGateway.deleteService(
            module: module,
            profile: gatewayProfile,
          );
        } on DioException catch (error) {
          if (error.response?.statusCode != 503) rethrow;
        }
        profile.setConnectionMode(module, LunaConnectionMode.direct);
        profile.setGatewayProfile(module, '');
        profile.setEnabled(module, false);
        await store.update(store.activeProfile, profile);
        showLunaSuccessSnackBar(
          title: 'settings.DeleteGatewayConnectionSuccess'.tr(),
          message: module.title,
        );
        onChanged();
      },
    );
  }

  static Future<bool> testGateway({
    required BuildContext context,
    required LunaModule module,
  }) async {
    final profile = LunaProfile.clone(context.read<ProfilesStore>().active);
    final gatewayProfile = _gatewayProfile(profile, module);
    await LunaGateway.testService(
      module: module,
      profile: gatewayProfile,
    );
    await _useGatewayProfile(context, profile, module, gatewayProfile);
    return true;
  }

  static Future<void> _configureGatewayUpstream({
    required BuildContext context,
    required LunaModule module,
    required VoidCallback onChanged,
  }) async {
    final profile = LunaProfile.clone(context.read<ProfilesStore>().active);
    final gatewayProfile = _gatewayProfile(profile, module);
    final existing = await _findGatewayService(module, gatewayProfile);
    final values = await SettingsDialogs().editGatewayUpstream(
      context,
      upstream: existing?['upstreamUrl']?.toString() ?? profile.host(module),
    );
    if (!values.item1) return;

    try {
      final service = await LunaGateway.putService(
        module: module,
        profile: gatewayProfile,
        upstreamUrl: values.item2,
      );
      if (_hasCompleteCredential(module, service)) {
        await _testAndUseGatewayProfile(
            context, profile, module, gatewayProfile);
      }
      onChanged();
    } catch (error, trace) {
      LunaLogger().error('Service Connection Failed', error, trace);
      showLunaErrorSnackBar(
        title: 'settings.ConnectionTestFailed'.tr(),
        error: error,
      );
    }
  }

  static Future<void> _configureGatewayApiKey({
    required BuildContext context,
    required LunaModule module,
    required VoidCallback onChanged,
  }) async {
    final profile = LunaProfile.clone(context.read<ProfilesStore>().active);
    final gatewayProfile = _gatewayProfile(profile, module);
    final values = await SettingsDialogs().editGatewayApiKey(context);
    if (!values.item1) return;

    try {
      await LunaGateway.putService(
        module: module,
        profile: gatewayProfile,
        apiKey: values.item2,
      );
      await _testAndUseGatewayProfile(context, profile, module, gatewayProfile);
      onChanged();
    } catch (error, trace) {
      LunaLogger().error('Service Connection Failed', error, trace);
      showLunaErrorSnackBar(
        title: 'settings.ConnectionTestFailed'.tr(),
        error: error,
      );
    }
  }

  static Future<void> _configureGatewayCredentials({
    required BuildContext context,
    required LunaModule module,
    required VoidCallback onChanged,
  }) async {
    final profile = LunaProfile.clone(context.read<ProfilesStore>().active);
    final gatewayProfile = _gatewayProfile(profile, module);
    final values = await SettingsDialogs().editGatewayCredentials(context);
    if (!values.item1) return;

    try {
      await LunaGateway.putService(
        module: module,
        profile: gatewayProfile,
        username: values.item2,
        password: values.item3,
      );
      await _testAndUseGatewayProfile(context, profile, module, gatewayProfile);
      onChanged();
    } catch (error, trace) {
      LunaLogger().error('Service Connection Failed', error, trace);
      showLunaErrorSnackBar(
        title: 'settings.ConnectionTestFailed'.tr(),
        error: error,
      );
    }
  }

  static Future<void> _testAndUseGatewayProfile(
    BuildContext context,
    LunaProfile profile,
    LunaModule module,
    String gatewayProfile,
  ) async {
    await LunaGateway.testService(
      module: module,
      profile: gatewayProfile,
    );
    await _useGatewayProfile(context, profile, module, gatewayProfile);
    showLunaSuccessSnackBar(
      title: 'settings.ConnectedSuccessfully'.tr(),
      message: 'settings.ConnectedSuccessfullyMessage'.tr(
        args: [module.title],
      ),
    );
  }

  static Future<void> _useGatewayProfile(
    BuildContext context,
    LunaProfile profile,
    LunaModule module,
    String gatewayProfile,
  ) async {
    profile.setConnectionMode(module, LunaConnectionMode.gateway);
    profile.setGatewayProfile(module, gatewayProfile);
    profile.setHost(module, '');
    _clearBrowserSecret(profile, module);
    profile.setEnabled(module, true);
    final store = context.read<ProfilesStore>();
    await store.update(store.activeProfile, profile);
  }

  static String _gatewayProfile(LunaProfile profile, LunaModule module) {
    return LunaServiceEndpoint.gatewayProfileFor(profile, module);
  }

  static Future<Map<String, dynamic>?> _findGatewayService(
    LunaModule module,
    String profile,
  ) async {
    try {
      return LunaGateway.fetchServiceConnection(
        module: module,
        profile: profile,
      );
    } catch (_) {}
    return null;
  }

  static bool _hasCompleteCredential(
    LunaModule module,
    Map<String, dynamic>? service,
  ) {
    if (service == null) return false;
    if (module == LunaModule.NZBGET) {
      return service['hasUsername'] == true && service['hasPassword'] == true;
    }
    return service['hasApiKey'] == true;
  }

  static void _clearBrowserSecret(LunaProfile profile, LunaModule module) {
    switch (module) {
      case LunaModule.LIDARR:
        profile.lidarrKey = '';
        return;
      case LunaModule.NZBGET:
        profile.nzbgetUser = '';
        profile.nzbgetPass = '';
        return;
      case LunaModule.RADARR:
        profile.radarrKey = '';
        return;
      case LunaModule.SABNZBD:
        profile.sabnzbdKey = '';
        return;
      case LunaModule.SONARR:
        profile.sonarrKey = '';
        return;
      case LunaModule.TAUTULLI:
        profile.tautulliKey = '';
        return;
      default:
        return;
    }
  }
}
