import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/nzbget.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/system/gateway/service_endpoint.dart';

class ConfigurationNZBGetConnectionDetailsRoute extends StatefulWidget {
  const ConfigurationNZBGetConnectionDetailsRoute({
    super.key,
  });

  @override
  State<ConfigurationNZBGetConnectionDetailsRoute> createState() => _State();
}

class _State extends State<ConfigurationNZBGetConnectionDetailsRoute>
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
                module: LunaModule.NZBGET,
                onChanged: () => context.read<NZBGetState>().reset(),
              ),
              if (SettingsServiceConnection.isGatewayConfigured(
                context,
                LunaModule.NZBGET,
              ))
                SettingsServiceConnection.deleteGatewayBlock(
                  context: context,
                  module: LunaModule.NZBGET,
                  onChanged: () => context.read<NZBGetState>().reset(),
                ),
            ] else ...[
              _host(),
              _username(),
              _password(),
              _customHeaders(),
            ],
          ],
        );
      },
    );
  }

  Widget _host() {
    final host = context.watch<ProfilesStore>().active.nzbgetHost;
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
            profile.nzbgetHost = _values.item2;
          });
          context.read<NZBGetState>().reset();
        }
      },
    );
  }

  Widget _username() {
    final username = context.watch<ProfilesStore>().active.nzbgetUser;
    return LunaBlock(
      title: 'settings.Username'.tr(),
      body: [
        TextSpan(text: username.isEmpty ? 'lunasea.NotSet'.tr() : username),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> _values = await LunaDialogs().editText(
          context,
          'settings.Username'.tr(),
          prefill: username,
        );
        if (_values.item1) {
          await context.read<ProfilesStore>().updateActive((profile) {
            profile.nzbgetUser = _values.item2;
          });
          context.read<NZBGetState>().reset();
        }
      },
    );
  }

  Widget _password() {
    final password = context.watch<ProfilesStore>().active.nzbgetPass;
    return LunaBlock(
      title: 'settings.Password'.tr(),
      body: [
        TextSpan(
          text: password.isEmpty
              ? 'lunasea.NotSet'.tr()
              : LunaUI.TEXT_OBFUSCATED_PASSWORD,
        ),
      ],
      trailing: const LunaIconButton.arrow(),
      onTap: () async {
        Tuple2<bool, String> _values = await LunaDialogs().editText(
          context,
          'settings.Password'.tr(),
          prefill: password,
          extraText: [
            LunaDialog.textSpanContent(
              text: '${LunaUI.TEXT_BULLET} ${'settings.PasswordHint1'.tr()}',
            ),
          ],
        );
        if (_values.item1) {
          await context.read<ProfilesStore>().updateActive((profile) {
            profile.nzbgetPass = _values.item2;
          });
          context.read<NZBGetState>().reset();
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
            module: LunaModule.NZBGET,
          )
              .then((_) => showLunaSuccessSnackBar(
                    title: 'settings.ConnectedSuccessfully'.tr(),
                    message: 'settings.ConnectedSuccessfullyMessage'
                        .tr(args: [LunaModule.NZBGET.title]),
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
          LunaModule.NZBGET,
        );
        if (_profile.nzbgetHost.isEmpty) {
          showLunaErrorSnackBar(
            title: 'settings.HostRequired'.tr(),
            message: 'settings.HostRequiredMessage'
                .tr(args: [LunaModule.NZBGET.title]),
          );
          return;
        }
        NZBGetAPI.from(LunaProfile.clone(_profile)..nzbgetHost = endpoint.base)
            .testConnection()
            .then((_) => showLunaSuccessSnackBar(
                  title: 'settings.ConnectedSuccessfully'.tr(),
                  message: 'settings.ConnectedSuccessfullyMessage'
                      .tr(args: [LunaModule.NZBGET.title]),
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
      onTap: SettingsRoutes.CONFIGURATION_NZBGET_CONNECTION_DETAILS_HEADERS.go,
    );
  }
}
