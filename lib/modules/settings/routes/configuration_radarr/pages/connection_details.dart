import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class ConfigurationRadarrConnectionDetailsRoute extends StatefulWidget {
  const ConfigurationRadarrConnectionDetailsRoute({
    super.key,
  });

  @override
  State<ConfigurationRadarrConnectionDetailsRoute> createState() => _State();
}

class _State extends State<ConfigurationRadarrConnectionDetailsRoute>
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
                module: LunaModule.RADARR,
                onChanged: () => context.read<RadarrState>().reset(),
              ),
              if (SettingsServiceConnection.isGatewayConfigured(
                context,
                LunaModule.RADARR,
              ))
                SettingsServiceConnection.deleteGatewayBlock(
                  context: context,
                  module: LunaModule.RADARR,
                  onChanged: () => context.read<RadarrState>().reset(),
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
    final host = context.watch<ProfilesStore>().active.radarrHost;
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
            profile.radarrHost = _values.item2;
          });
          context.read<RadarrState>().reset();
        }
      },
    );
  }

  Widget _apiKey() {
    final apiKey = context.watch<ProfilesStore>().active.radarrKey;
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
            profile.radarrKey = _values.item2;
          });
          context.read<RadarrState>().reset();
        }
      },
    );
  }

  Widget _testConnection() {
    return LunaButton.text(
      text: 'settings.TestConnection'.tr(),
      icon: LunaIcons.CONNECTION_TEST,
      onTap: () async {
        final _profile = context.read<ProfilesStore>().active;
        if (SettingsServiceConnection.gatewayAvailable) {
          return SettingsServiceConnection.testGateway(
            context: context,
            module: LunaModule.RADARR,
          )
              .then(
            (_) => showLunaSuccessSnackBar(
              title: 'settings.ConnectedSuccessfully'.tr(),
              message: 'settings.ConnectedSuccessfullyMessage'
                  .tr(args: [LunaModule.RADARR.title]),
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
        final endpoint = LunaServiceEndpoint.fromProfile(
          _profile,
          LunaModule.RADARR,
        );
        if (_profile.radarrHost.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.HostRequired'.tr(),
            message: 'settings.HostRequiredMessage'
                .tr(args: [LunaModule.RADARR.title]),
          );
          return;
        }
        if (_profile.radarrKey.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.ApiKeyRequired'.tr(),
            message: 'settings.ApiKeyRequiredMessage'
                .tr(args: [LunaModule.RADARR.title]),
          );
          return;
        }
        RadarrAPI(
          host: endpoint.base,
          apiKey: _profile.radarrKey,
          headers: Map<String, dynamic>.from(_profile.radarrHeaders),
        )
            .system
            .status()
            .then(
              (_) => showLunaSuccessSnackBar(
                title: 'settings.ConnectedSuccessfully'.tr(),
                message: 'settings.ConnectedSuccessfullyMessage'
                    .tr(args: [LunaModule.RADARR.title]),
              ),
            )
            .catchError(
          (error, trace) {
            LunaLogger().error(
              'Connection Test Failed',
              error,
              trace,
            );
            showLunaErrorSnackBar(
              title: 'settings.ConnectionTestFailed'.tr(),
              error: error,
            );
          },
        );
      },
    );
  }

  Widget _customHeaders() {
    return LunaBlock(
      title: 'settings.CustomHeaders'.tr(),
      body: [TextSpan(text: 'settings.CustomHeadersDescription'.tr())],
      trailing: const LunaIconButton.arrow(),
      onTap: SettingsRoutes.CONFIGURATION_RADARR_CONNECTION_DETAILS_HEADERS.go,
    );
  }
}
