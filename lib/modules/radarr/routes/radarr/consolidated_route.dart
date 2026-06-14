import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/router/routes/radarr.dart';
import 'package:lunasea/system/consolidated/instance_picker_sheet.dart';

/// Module shell for the consolidated Radarr view (path: `/radarr`).
///
/// Aggregates all enabled Radarr instances into a single navigable module with
/// the same four tabs as the per-instance view.  The app-bar dropdown lets the
/// user jump into a specific instance or return to "All Instances".
class RadarrConsolidatedRoute extends StatefulWidget {
  final int? initialPage;

  const RadarrConsolidatedRoute({super.key, this.initialPage});

  @override
  State<RadarrConsolidatedRoute> createState() => _State();
}

class _State extends State<RadarrConsolidatedRoute> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  LunaPageController? _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = LunaPageController(
      initialPage:
          widget.initialPage ?? RadarrPreferences.NAVIGATION_INDEX.read(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      module: LunaModule.RADARR,
      drawer: _drawer(),
      appBar: _appBar() as PreferredSizeWidget?,
      bottomNavigationBar: _bottomNavigationBar(),
      body: _body(),
    );
  }

  void _onAddPressed() {
    final instances = context.read<RadarrConsolidatedState>().instances;
    if (instances.isEmpty) return;
    LunaInstancePickerSheet().show(instances: instances).then((id) {
      if (id != null) RadarrRoutes.ADD_MOVIE.goInstance(instanceId: id);
    });
  }

  Widget _drawer() {
    return LunaDrawer(page: LunaModule.RADARR.key);
  }

  Widget? _bottomNavigationBar() {
    return RadarrNavigationBar(pageController: _pageController);
  }

  Widget _appBar() {
    final consolidated = context.watch<RadarrConsolidatedState>();
    final instances = consolidated.instances;
    List<Widget>? actions;

    if (consolidated.instanceStates.any((s) => s.enabled)) {
      actions = [
        RadarrAppBarAddMoviesAction(onPressed: _onAddPressed),
        const RadarrAppBarGlobalSettingsAction(),
      ];
    }

    return LunaAppBar.instanceFilter(
      title: LunaModule.RADARR.title,
      instances: instances,
      onInstanceSelected: (instanceId) =>
          RadarrRoutes.HOME.goInstance(instanceId: instanceId, buildTree: true),
      actions: actions,
      pageController: _pageController,
      scrollControllers: RadarrNavigationBar.scrollControllers,
    );
  }

  Widget _body() {
    return LunaPageView(
      controller: _pageController,
      children: const [
        RadarrConsolidatedCatalogueRoute(),
        RadarrConsolidatedUpcomingRoute(),
        RadarrConsolidatedMissingRoute(),
        RadarrConsolidatedMoreRoute(),
      ],
    );
  }
}
