import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/modules/tautulli.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class ConfigurationTautulliConnectionDetailsRoute extends StatefulWidget {
  const ConfigurationTautulliConnectionDetailsRoute({
    super.key,
  });

  @override
  State<ConfigurationTautulliConnectionDetailsRoute> createState() => _State();
}

class _State extends State<ConfigurationTautulliConnectionDetailsRoute>
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
                module: LunaModule.TAUTULLI,
                onChanged: () => context.read<TautulliState>().reset(),
              ),
              if (SettingsServiceConnection.isGatewayConfigured(
                context,
                LunaModule.TAUTULLI,
              ))
                SettingsServiceConnection.deleteGatewayBlock(
                  context: context,
                  module: LunaModule.TAUTULLI,
                  onChanged: () => context.read<TautulliState>().reset(),
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
    final host = context.watch<ProfilesStore>().active.tautulliHost;
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
            profile.tautulliHost = _values.item2;
          });
          context.read<TautulliState>().reset();
        }
      },
    );
  }

  Widget _apiKey() {
    final apiKey = context.watch<ProfilesStore>().active.tautulliKey;
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
            profile.tautulliKey = _values.item2;
          });
          context.read<TautulliState>().reset();
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
            module: LunaModule.TAUTULLI,
          )
              .then((_) => showLunaSuccessSnackBar(
                    title: 'settings.ConnectedSuccessfully'.tr(),
                    message: 'settings.ConnectedSuccessfullyMessage'
                        .tr(args: [LunaModule.TAUTULLI.title]),
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
          LunaModule.TAUTULLI,
        );
        if (_profile.tautulliHost.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.HostRequired'.tr(),
            message: 'settings.HostRequiredMessage'
                .tr(args: [LunaModule.TAUTULLI.title]),
          );
          return;
        }
        if (_profile.tautulliKey.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.ApiKeyRequired'.tr(),
            message: 'settings.ApiKeyRequiredMessage'
                .tr(args: [LunaModule.TAUTULLI.title]),
          );
          return;
        }
        TautulliAPI(
                host: endpoint.base,
                apiKey: _profile.tautulliKey,
                headers: Map<String, dynamic>.from(_profile.tautulliHeaders))
            .miscellaneous
            .arnold()
            .then((_) => showLunaSuccessSnackBar(
                  title: 'settings.ConnectedSuccessfully'.tr(),
                  message: 'settings.ConnectedSuccessfullyMessage'
                      .tr(args: [LunaModule.TAUTULLI.title]),
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
      onTap:
          SettingsRoutes.CONFIGURATION_TAUTULLI_CONNECTION_DETAILS_HEADERS.go,
    );
  }
}
