import 'package:flutter/material.dart';

import 'package:lunasea/core.dart';
import 'package:lunasea/system/preferences/bios.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/system/network/network.dart';
import 'package:lunasea/system/platform.dart';

class ConfigurationGeneralRoute extends StatefulWidget {
  const ConfigurationGeneralRoute({
    Key? key,
  }) : super(key: key);

  @override
  State createState() => _State();
}

class _State extends State<ConfigurationGeneralRoute>
    with LunaScrollControllerMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: _appBar(),
      body: _body(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar(
      title: 'settings.General'.tr(),
      scrollControllers: [scrollController],
    );
  }

  Widget _body() {
    return LunaListView(
      controller: scrollController,
      children: [
        ..._appearance(),
        ..._localization(),
        ..._modules(),
        if (LunaNetwork.isSupported) ..._network(),
        ..._platform(),
      ],
    );
  }

  List<Widget> _appearance() {
    return [
      LunaHeader(text: 'settings.Appearance'.tr()),
      _imageBackgroundOpacity(),
      _amoledTheme(),
      _amoledThemeBorders(),
    ];
  }

  List<Widget> _localization() {
    return [
      LunaHeader(text: 'settings.Localization'.tr()),
      _use24HourTime(),
    ];
  }

  List<Widget> _modules() {
    return [
      LunaHeader(text: 'dashboard.Modules'.tr()),
      _bootModule(),
    ];
  }

  List<Widget> _network() {
    return [
      LunaHeader(text: 'settings.Network'.tr()),
      _useTLSValidation(),
    ];
  }

  List<Widget> _platform() {
    if (LunaPlatform.isAndroid) {
      return [
        LunaHeader(text: 'settings.Platform'.tr()),
        _openDrawerOnBackAction(),
      ];
    }

    return [];
  }

  Widget _openDrawerOnBackAction() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.OpenDrawerOnBackAction'.tr(),
        body: [
          TextSpan(text: 'settings.OpenDrawerOnBackActionDescription'.tr()),
        ],
        trailing: LunaSwitch(
          value: settings.androidBackOpensDrawer,
          onChanged: settings.setAndroidBackOpensDrawer,
        ),
      ),
    );
  }

  Widget _amoledTheme() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.AmoledTheme'.tr(),
        body: [
          TextSpan(text: 'settings.AmoledThemeDescription'.tr()),
        ],
        trailing: LunaSwitch(
          value: settings.amoledTheme,
          onChanged: (value) {
            settings.setAmoledTheme(value);
            LunaTheme().initialize();
          },
        ),
      ),
    );
  }

  Widget _amoledThemeBorders() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.AmoledThemeBorders'.tr(),
        body: [
          TextSpan(text: 'settings.AmoledThemeBordersDescription'.tr()),
        ],
        trailing: LunaSwitch(
          value: settings.amoledThemeBorder,
          onChanged:
              settings.amoledTheme ? settings.setAmoledThemeBorder : null,
        ),
      ),
    );
  }

  Widget _imageBackgroundOpacity() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.BackgroundImageOpacity'.tr(),
        body: [
          TextSpan(
              text: settings.imageBackgroundOpacity == 0
                  ? 'lunasea.Disabled'.tr()
                  : '${settings.imageBackgroundOpacity}%'),
        ],
        trailing: const LunaIconButton.arrow(),
        onTap: () async {
          Tuple2<bool, int> result =
              await SettingsDialogs().changeBackgroundImageOpacity(context);
          if (result.item1) settings.setImageBackgroundOpacity(result.item2);
        },
      ),
    );
  }

  Widget _useTLSValidation() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.TLSCertificateValidation'.tr(),
        body: [
          TextSpan(text: 'settings.TLSCertificateValidationDescription'.tr()),
        ],
        trailing: LunaSwitch(
          value: settings.tlsValidation,
          onChanged: (data) {
            settings.setTlsValidation(data);
            if (LunaNetwork.isSupported) LunaNetwork().initialize();
          },
        ),
      ),
    );
  }

  Widget _use24HourTime() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.Use24HourTime'.tr(),
        body: [TextSpan(text: 'settings.Use24HourTimeDescription'.tr())],
        trailing: LunaSwitch(
          value: settings.use24HourTime,
          onChanged: settings.setUse24HourTime,
        ),
      ),
    );
  }

  Widget _bootModule() {
    return Consumer<SettingsStore>(
      builder: (context, settings, _) => LunaBlock(
        title: 'settings.BootModule'.tr(),
        body: [TextSpan(text: settings.bootModule.title)],
        trailing: LunaIconButton(icon: settings.bootModule.icon),
        onTap: () async {
          final result = await SettingsDialogs().selectBootModule();
          if (result.item1) {
            settings.setBootModule(result.item2!);
          }
        },
      ),
    );
  }
}
