import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/extensions/string/links.dart';
import 'package:lunasea/modules/lidarr.dart';
import 'package:lunasea/router/routes/lidarr.dart';

class LidarrRoute extends StatefulWidget {
  final LunaServiceInstance instance;

  const LidarrRoute({super.key, required this.instance});

  @override
  State<LidarrRoute> createState() => _State();
}

class _State extends State<LidarrRoute> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  LunaPageController? _pageController;
  String _profileState = '';
  late LidarrAPI _api;

  final List _refreshKeys = [
    GlobalKey<RefreshIndicatorState>(),
    GlobalKey<RefreshIndicatorState>(),
    GlobalKey<RefreshIndicatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = LunaPageController(
      initialPage: LidarrPreferences.NAVIGATION_INDEX.read(),
    );
    _refreshProfile(refreshPages: false);
  }

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      body: _body(),
      drawer: _drawer(),
      appBar: _appBar() as PreferredSizeWidget?,
      bottomNavigationBar: _bottomNavigationBar(),
      onProfileChange: (_) {
        if (_profileState != context.read<ProfilesStore>().active.toString()) {
          _refreshProfile();
        }
      },
    );
  }

  Widget _drawer() => LunaDrawer(page: LunaModule.LIDARR.key);

  Widget? _bottomNavigationBar() {
    if (widget.instance.enabled)
      return LidarrNavigationBar(pageController: _pageController);
    return null;
  }

  Widget _body() {
    if (!widget.instance.enabled)
      return LunaMessage.moduleNotEnabled(
        context: context,
        module: LunaModule.LIDARR.title,
      );
    return LunaPageView(
      controller: _pageController,
      children: [
        LidarrCatalogue(
          refreshIndicatorKey: _refreshKeys[0],
          refreshAllPages: _refreshAllPages,
        ),
        LidarrMissing(
          refreshIndicatorKey: _refreshKeys[1],
          refreshAllPages: _refreshAllPages,
        ),
        LidarrHistory(
          refreshIndicatorKey: _refreshKeys[2],
          refreshAllPages: _refreshAllPages,
        ),
      ],
    );
  }

  Widget _appBar() {
    final profiles = context.watch<ProfilesStore>().enabledFor(
      LunaModule.LIDARR,
    );
    List<Widget>? actions;
    if (widget.instance.enabled)
      actions = [
        LunaIconButton(
          icon: Icons.add_rounded,
          onPressed: () async => _enterAddArtist(),
        ),
        LunaIconButton(
          icon: Icons.more_vert_rounded,
          onPressed: () async => _handlePopup(),
        ),
      ];
    return LunaAppBar.dropdown(
      title: LunaModule.LIDARR.title,
      useDrawer: true,
      profiles: profiles,
      actions: actions,
      pageController: _pageController,
      scrollControllers: LidarrNavigationBar.scrollControllers,
    );
  }

  Future<void> _enterAddArtist() async {
    final _model = Provider.of<LidarrState>(context, listen: false);
    _model.addSearchQuery = '';
    LidarrRoutes.ADD_ARTIST.go();
  }

  Future<void> _handlePopup() async {
    List<dynamic> values = await LidarrDialogs.globalSettings(context);
    if (values[0])
      switch (values[1]) {
        case 'web_gui':
          await widget.instance.host.openLink();
          break;
        case 'update_library':
          await _api
              .updateLibrary()
              .then(
                (_) => showLunaSuccessSnackBar(
                  title: 'Updating Library...',
                  message: 'Updating your library in the background',
                ),
              )
              .catchError(
                (error) => showLunaErrorSnackBar(
                  title: 'Failed to Update Library',
                  error: error,
                ),
              );
          break;
        case 'rss_sync':
          await _api
              .triggerRssSync()
              .then(
                (_) => showLunaSuccessSnackBar(
                  title: 'Running RSS Sync...',
                  message: 'Running RSS sync in the background',
                ),
              )
              .catchError(
                (error) => showLunaErrorSnackBar(
                  title: 'Failed to Run RSS Sync',
                  error: error,
                ),
              );
          break;
        case 'backup':
          await _api
              .triggerBackup()
              .then(
                (_) => showLunaSuccessSnackBar(
                  title: 'Backing Up Database...',
                  message: 'Backing up database in the background',
                ),
              )
              .catchError(
                (error) => showLunaErrorSnackBar(
                  title: 'Failed to Backup Database',
                  error: error,
                ),
              );
          break;
        case 'missing_search':
          {
            List<dynamic> values = await LidarrDialogs.searchAllMissing(
              context,
            );
            if (values[0])
              await _api
                  .searchAllMissing()
                  .then(
                    (_) => showLunaSuccessSnackBar(
                      title: 'Searching...',
                      message: 'Search for all missing albums',
                    ),
                  )
                  .catchError(
                    (error) => showLunaErrorSnackBar(
                      title: 'Failed to Search',
                      error: error,
                    ),
                  );
            break;
          }
        default:
          LunaLogger().warning('Unknown Case: ${values[1]}');
      }
  }

  void _refreshProfile({bool refreshPages = true}) {
    _api = LidarrAPI.fromInstance(widget.instance);
    _profileState = widget.instance.key;
    if (refreshPages) _refreshAllPages();
  }

  void _refreshAllPages() {
    for (var key in _refreshKeys) key?.currentState?.show();
  }
}
