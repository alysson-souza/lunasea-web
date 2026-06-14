import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/router/routes/sonarr.dart';
import 'package:lunasea/system/consolidated/instance_picker_sheet.dart';

/// Module shell for the consolidated Sonarr view (path: `/sonarr`).
///
/// Aggregates all enabled Sonarr instances into a single navigable module with
/// the same four tabs as the per-instance view.  The app-bar dropdown lets the
/// user jump into a specific instance or return to "All Instances".
class SonarrConsolidatedRoute extends StatefulWidget {
  final int? initialPage;

  const SonarrConsolidatedRoute({super.key, this.initialPage});

  @override
  State<SonarrConsolidatedRoute> createState() => _State();
}

class _State extends State<SonarrConsolidatedRoute> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  LunaPageController? _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = LunaPageController(
      initialPage:
          widget.initialPage ?? SonarrPreferences.NAVIGATION_INDEX.read(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      module: LunaModule.SONARR,
      drawer: _drawer(),
      appBar: _appBar() as PreferredSizeWidget?,
      bottomNavigationBar: _bottomNavigationBar(),
      body: _body(),
    );
  }

  void _onAddPressed() {
    final instances = context.read<SonarrConsolidatedState>().instances;
    if (instances.isEmpty) return;
    LunaInstancePickerSheet().show(instances: instances).then((id) {
      if (id != null) SonarrRoutes.ADD_SERIES.goInstance(instanceId: id);
    });
  }

  Widget _drawer() {
    return LunaDrawer(page: LunaModule.SONARR.key);
  }

  Widget? _bottomNavigationBar() {
    return SonarrNavigationBar(pageController: _pageController);
  }

  Widget _appBar() {
    final consolidated = context.watch<SonarrConsolidatedState>();
    final instances = consolidated.instances;
    List<Widget>? actions;

    if (consolidated.instanceStates.any((s) => s.enabled)) {
      actions = [
        SonarrAppBarAddSeriesAction(onPressed: _onAddPressed),
        const SonarrAppBarGlobalSettingsAction(),
      ];
    }

    return LunaAppBar.instanceFilter(
      title: LunaModule.SONARR.title,
      instances: instances,
      onInstanceSelected: (instanceId) =>
          SonarrRoutes.HOME.goInstance(instanceId: instanceId, buildTree: true),
      actions: actions,
      pageController: _pageController,
      scrollControllers: SonarrNavigationBar.scrollControllers,
    );
  }

  Widget _body() {
    return LunaPageView(
      controller: _pageController,
      children: const [
        SonarrConsolidatedCatalogueRoute(),
        SonarrConsolidatedUpcomingRoute(),
        SonarrConsolidatedMissingRoute(),
        SonarrConsolidatedMoreRoute(),
      ],
    );
  }
}
