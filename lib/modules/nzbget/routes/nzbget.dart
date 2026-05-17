import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/system/preferences/nzbget.dart';
import 'package:lunasea/extensions/string/links.dart';
import 'package:lunasea/modules/nzbget.dart';
import 'package:lunasea/router/routes/nzbget.dart';

import 'package:lunasea/system/filesystem/file.dart';
import 'package:lunasea/system/filesystem/filesystem.dart';

class NZBGetRoute extends StatefulWidget {
  final LunaServiceInstance? instance;
  final bool showDrawer;

  const NZBGetRoute({super.key, this.instance, this.showDrawer = true});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<NZBGetRoute> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  LunaPageController? _pageController;
  String _profileState = '';
  late NZBGetAPI _api;

  final List _refreshKeys = [
    GlobalKey<RefreshIndicatorState>(),
    GlobalKey<RefreshIndicatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = LunaPageController(
      initialPage: NZBGetPreferences.NAVIGATION_INDEX.read(),
    );
    _refreshProfile(refreshPages: false);
  }

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      body: _body(),
      drawer: widget.showDrawer ? _drawer() : null,
      appBar: _appBar() as PreferredSizeWidget?,
      bottomNavigationBar: _bottomNavigationBar(),
      extendBodyBehindAppBar: false,
      extendBody: false,
      onProfileChange: (_) {
        if (_profileState != context.read<ProfilesStore>().active.toString()) {
          _refreshProfile();
        }
      },
    );
  }

  Widget _drawer() => LunaDrawer(page: LunaModule.NZBGET.key);

  Widget? _bottomNavigationBar() {
    if (widget.instance?.enabled ??
        context.watch<ProfilesStore>().active.isModuleAvailable(
          LunaModule.NZBGET,
        )) {
      return NZBGetNavigationBar(pageController: _pageController);
    }
    return null;
  }

  Widget _appBar() {
    final profiles = context.watch<ProfilesStore>().enabledFor(
      LunaModule.NZBGET,
    );
    List<Widget>? actions;
    if (widget.instance?.enabled ??
        context.watch<ProfilesStore>().active.isModuleAvailable(
          LunaModule.NZBGET,
        ))
      actions = [
        Selector<NZBGetState, bool>(
          selector: (_, model) => model.error,
          builder: (context, error, widget) =>
              error ? Container() : const NZBGetAppBarStats(),
        ),
        LunaIconButton(
          icon: Icons.more_vert_rounded,
          onPressed: () async => _handlePopup(),
        ),
      ];
    return LunaAppBar.dropdown(
      title: LunaModule.NZBGET.title,
      useDrawer: widget.showDrawer,
      hideLeading: !widget.showDrawer,
      profiles: profiles,
      actions: actions,
      pageController: _pageController,
      scrollControllers: NZBGetNavigationBar.scrollControllers,
    );
  }

  Widget _body() {
    if (!(widget.instance?.enabled ??
        context.watch<ProfilesStore>().active.isModuleAvailable(
          LunaModule.NZBGET,
        )))
      return LunaMessage.moduleNotEnabled(
        context: context,
        module: LunaModule.NZBGET.title,
      );
    return LunaPageView(
      controller: _pageController,
      children: [
        NZBGetQueue(refreshIndicatorKey: _refreshKeys[0]),
        NZBGetHistory(refreshIndicatorKey: _refreshKeys[1]),
      ],
    );
  }

  Future<void> _handlePopup() async {
    List<dynamic> values = await NZBGetDialogs.globalSettings(context);
    if (values[0])
      switch (values[1]) {
        case 'web_gui':
          await context
              .read<NZBGetState>()
              .selectedInstance(context)
              ?.host
              .openLink();
          break;
        case 'add_nzb':
          _addNZB();
          break;
        case 'sort':
          _sort();
          break;
        case 'server_details':
          _serverDetails();
          break;
        default:
          LunaLogger().warning('Unknown Case: ${values[1]}');
      }
  }

  Future<void> _addNZB() async {
    List values = await NZBGetDialogs.addNZB(context);
    if (values[0])
      switch (values[1]) {
        case 'link':
          _addByURL();
          break;
        case 'file':
          _addByFile();
          break;
        default:
          LunaLogger().warning('Unknown Case: ${values[1]}');
      }
  }

  Future<void> _addByURL() async {
    List values = await NZBGetDialogs.addNZBUrl(context);
    if (values[0])
      await _api
          .uploadURL(values[1])
          .then(
            (_) => showLunaSuccessSnackBar(
              title: 'Uploaded NZB (URL)',
              message: values[1],
            ),
          )
          .catchError(
            (error) => showLunaErrorSnackBar(
              title: 'Failed to Upload NZB',
              error: error,
            ),
          );
  }

  Future<void> _addByFile() async {
    try {
      LunaFile? _file = await LunaFileSystem().read(context, ['nzb']);
      if (_file != null) {
        if (_file.data.isNotEmpty) {
          await _api.uploadFile(_file.data, _file.name).then((value) {
            _refreshKeys[0]?.currentState?.show();
            showLunaSuccessSnackBar(
              title: 'Uploaded NZB (File)',
              message: _file.name,
            );
          });
        } else {
          showLunaErrorSnackBar(
            title: 'Failed to Upload NZB',
            message: 'Please select a valid file',
          );
        }
      }
    } catch (error, stack) {
      LunaLogger().error('Failed to add NZB by file', error, stack);
      showLunaErrorSnackBar(title: 'Failed to Upload NZB', error: error);
    }
  }

  Future<void> _sort() async {
    List values = await NZBGetDialogs.sortQueue(context);
    if (values[0])
      await _api
          .sortQueue(values[1])
          .then((_) {
            _refreshKeys[0]?.currentState?.show();
            showLunaSuccessSnackBar(
              title: 'Sorted Queue',
              message: (values[1] as NZBGetSort?).name,
            );
          })
          .catchError((error) {
            showLunaErrorSnackBar(title: 'Failed to Sort Queue', error: error);
          });
  }

  Future<void> _serverDetails() async => NZBGetRoutes.STATISTICS.go();

  void _refreshProfile({bool refreshPages = true}) {
    final profile = context.read<ProfilesStore>().active;
    final instance = widget.instance;
    _api = instance != null
        ? NZBGetAPI.fromInstance(instance)
        : NZBGetAPI.from(profile);
    _profileState = instance?.key ?? profile.toString();
    if (refreshPages) _refreshAllPages();
  }

  void _refreshAllPages() {
    for (var key in _refreshKeys) key?.currentState?.show();
  }
}
