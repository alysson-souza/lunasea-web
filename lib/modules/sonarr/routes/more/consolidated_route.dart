import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/router/routes/sonarr.dart';

/// "More" tab for the consolidated Sonarr view.
///
/// Per-instance management screens (history, queue, tags) are not aggregated.
/// Instead this tab lists each enabled instance; tapping one navigates into
/// that instance's dedicated per-instance view.
class SonarrConsolidatedMoreRoute extends StatefulWidget {
  const SonarrConsolidatedMoreRoute({super.key});

  @override
  State<SonarrConsolidatedMoreRoute> createState() => _State();
}

class _State extends State<SonarrConsolidatedMoreRoute>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LunaScaffold(scaffoldKey: _scaffoldKey, body: _body());
  }

  Widget _body() {
    final consolidated = context.read<SonarrConsolidatedState>();
    return LunaListView(
      controller: SonarrNavigationBar.scrollControllers[3],
      itemExtent: LunaBlock.calculateItemExtent(1),
      children: consolidated.instances.map((instance) {
        return LunaBlock(
          title: instance.displayName,
          body: [TextSpan(text: 'sonarr.OpenInstanceDescription'.tr())],
          trailing: LunaIconButton(
            icon: LunaModule.SONARR.icon,
            color: LunaModule.SONARR.color,
          ),
          onTap: () => SonarrRoutes.HOME.goInstance(
            instanceId: instance.id,
            buildTree: true,
          ),
        );
      }).toList(),
    );
  }
}
