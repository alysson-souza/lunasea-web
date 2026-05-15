import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class ConfigurationSonarrConnectionDetailsRoute extends StatefulWidget {
  const ConfigurationSonarrConnectionDetailsRoute({
    super.key,
  });

  @override
  State<ConfigurationSonarrConnectionDetailsRoute> createState() => _State();
}

class _State extends State<ConfigurationSonarrConnectionDetailsRoute>
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
                module: LunaModule.SONARR,
                onChanged: () => context.read<SonarrState>().reset(),
              ),
              if (SettingsServiceConnection.isGatewayConfigured(
                context,
                LunaModule.SONARR,
              ))
                SettingsServiceConnection.deleteGatewayBlock(
                  context: context,
                  module: LunaModule.SONARR,
                  onChanged: () => context.read<SonarrState>().reset(),
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
    final host = context.watch<ProfilesStore>().active.sonarrHost;
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
            profile.sonarrHost = _values.item2;
          });
          context.read<SonarrState>().reset();
        }
      },
    );
  }

  Widget _apiKey() {
    final apiKey = context.watch<ProfilesStore>().active.sonarrKey;
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
            profile.sonarrKey = _values.item2;
          });
          context.read<SonarrState>().reset();
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
            module: LunaModule.SONARR,
          )
              .then(
            (_) => showLunaSuccessSnackBar(
              title: 'settings.ConnectedSuccessfully'.tr(),
              message: 'settings.ConnectedSuccessfullyMessage'
                  .tr(args: [LunaModule.SONARR.title]),
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
          LunaModule.SONARR,
        );
        if (_profile.sonarrHost.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.HostRequired'.tr(),
            message: 'settings.HostRequiredMessage'
                .tr(args: [LunaModule.SONARR.title]),
          );
          return;
        }
        if (_profile.sonarrKey.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.ApiKeyRequired'.tr(),
            message: 'settings.ApiKeyRequiredMessage'
                .tr(args: [LunaModule.SONARR.title]),
          );
          return;
        }
        SonarrAPI(
          host: endpoint.base,
          apiKey: _profile.sonarrKey,
          headers: Map<String, dynamic>.from(
            _profile.sonarrHeaders,
          ),
        ).system.getStatus().then((_) {
          showLunaSuccessSnackBar(
            title: 'settings.ConnectedSuccessfully'.tr(),
            message: 'settings.ConnectedSuccessfullyMessage'
                .tr(args: [LunaModule.SONARR.title]),
          );
        }).catchError((error, trace) {
          LunaLogger().error(
            'Connection Test Failed',
            error,
            trace,
          );
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
      onTap: SettingsRoutes.CONFIGURATION_SONARR_CONNECTION_DETAILS_HEADERS.go,
    );
  }
}
