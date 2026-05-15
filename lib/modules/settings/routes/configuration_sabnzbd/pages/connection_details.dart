import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sabnzbd.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class ConfigurationSABnzbdConnectionDetailsRoute extends StatefulWidget {
  const ConfigurationSABnzbdConnectionDetailsRoute({
    super.key,
  });

  @override
  State<ConfigurationSABnzbdConnectionDetailsRoute> createState() => _State();
}

class _State extends State<ConfigurationSABnzbdConnectionDetailsRoute>
    with LunaScrollControllerMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar() as PreferredSizeWidget?,
      body: _body(),
      bottomNavigationBar: _bottomActionBar(),
    );
  }

  Widget _appBar() {
    return LunaAppBar(
      title: 'settings.ConnectionDetails'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _bottomActionBar() {
    return LunaBottomActionBar(
      actions: [
        _testConnection(),
      ],
    );
  }

  Widget _body() {
    return Consumer<ProfilesStore>(
      builder: (context, profiles, _) {
        return LunaListView(
          controller: scrollController,
          children: [
            if (SettingsServiceConnection.gatewayAvailable) ...[
              SettingsServiceConnection.gatewayBlock(
                context: context,
                module: LunaModule.SABNZBD,
                onChanged: () => context.read<SABnzbdState>().reset(),
              ),
              if (SettingsServiceConnection.isGatewayConfigured(
                context,
                LunaModule.SABNZBD,
              ))
                SettingsServiceConnection.deleteGatewayBlock(
                  context: context,
                  module: LunaModule.SABNZBD,
                  onChanged: () => context.read<SABnzbdState>().reset(),
                ),
            ] else ...[
              _host(),
              _apiKey(),
              _customHeaders(),
            ],
          ],
        );
      },
    );
  }

  Widget _host() {
    final host = context.watch<ProfilesStore>().active.sabnzbdHost;
    return LunaBlock(
      title: 'settings.Host'.tr(),
      body: [TextSpan(text: host.isEmpty ? 'lunasea.NotSet'.tr() : host)],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> _values = await SettingsDialogs().editHost(
          context,
          prefill: host,
        );
        if (_values.item1) {
          await context.read<ProfilesStore>().updateActive((profile) {
            profile.sabnzbdHost = _values.item2;
          });
          context.read<SABnzbdState>().reset();
        }
      },
    );
  }

  Widget _apiKey() {
    final apiKey = context.watch<ProfilesStore>().active.sabnzbdKey;
    return LunaBlock(
      title: 'settings.ApiKey'.tr(),
      body: [
        TextSpan(
          text: apiKey.isEmpty
              ? 'lunasea.NotSet'.tr()
              : LunaUI.TEXT_OBFUSCATED_PASSWORD,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> _values = await LunaDialogs().editText(
          context,
          'settings.ApiKey'.tr(),
          prefill: apiKey,
        );
        if (_values.item1) {
          await context.read<ProfilesStore>().updateActive((profile) {
            profile.sabnzbdKey = _values.item2;
          });
          context.read<SABnzbdState>().reset();
        }
      },
    );
  }

  Widget _testConnection() {
    return LunaButton.text(
      text: 'settings.TestConnection'.tr(),
      icon: Icons.wifi_tethering_rounded,
      onTap: () async {
        final _profile = context.read<ProfilesStore>().active;
        if (SettingsServiceConnection.gatewayAvailable) {
          return SettingsServiceConnection.testGateway(
            context: context,
            module: LunaModule.SABNZBD,
          )
              .then((_) => showLunaSuccessSnackBar(
                    title: 'settings.ConnectedSuccessfully'.tr(),
                    message: 'settings.ConnectedSuccessfullyMessage'
                        .tr(args: [LunaModule.SABNZBD.title]),
                  ))
              .catchError((error, trace) {
            LunaLogger().error('Connection Test Failed', error, trace);
            showLunaErrorSnackBar(
              title: 'settings.ConnectionTestFailed'.tr(),
              error: error,
            );
          });
        }
        final endpoint = LunaServiceEndpoint.fromProfile(
          _profile,
          LunaModule.SABNZBD,
        );
        if (_profile.sabnzbdHost.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.HostRequired'.tr(),
            message: 'settings.HostRequiredMessage'
                .tr(args: [LunaModule.SABNZBD.title]),
          );
          return;
        }
        if (_profile.sabnzbdKey.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.ApiKeyRequired'.tr(),
            message: 'settings.ApiKeyRequiredMessage'
                .tr(args: [LunaModule.SABNZBD.title]),
          );
          return;
        }
        SABnzbdAPI.from(
                LunaProfile.clone(_profile)..sabnzbdHost = endpoint.base)
            .testConnection()
            .then((_) => showLunaSuccessSnackBar(
                  title: 'settings.ConnectedSuccessfully'.tr(),
                  message: 'settings.ConnectedSuccessfullyMessage'
                      .tr(args: [LunaModule.SABNZBD.title]),
                ))
            .catchError((error, trace) {
          LunaLogger().error('Connection Test Failed', error, trace);
          showLunaErrorSnackBar(
            title: 'settings.ConnectionTestFailed'.tr(),
            error: error,
          );
        });
      },
    );
  }

  Widget _customHeaders() {
    return LunaBlock(
      title: 'settings.CustomHeaders'.tr(),
      body: [TextSpan(text: 'settings.CustomHeadersDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_SABNZBD_CONNECTION_DETAILS_HEADERS.go,
    );
  }
}
