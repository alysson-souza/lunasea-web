import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/router/routes/radarr.dart';

/// "More" tab for the consolidated Radarr view.
///
/// Per-instance management screens (history, queue, status, tags, imports) are
/// not aggregated.  Instead this tab lists each enabled instance and lets the
/// user jump into that instance's dedicated view.
class RadarrConsolidatedMoreRoute extends StatefulWidget {
  const RadarrConsolidatedMoreRoute({super.key});

  @override
  State<RadarrConsolidatedMoreRoute> createState() => _State();
}

class _State extends State<RadarrConsolidatedMoreRoute>
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
    final consolidated = context.read<RadarrConsolidatedState>();
    return LunaListView(
      controller: RadarrNavigationBar.scrollControllers[3],
      itemExtent: LunaBlock.calculateItemExtent(1),
      children: consolidated.instances.asMap().entries.map((entry) {
        final instance = entry.value;
        return LunaBlock(
          title: instance.displayName,
          body: [TextSpan(text: 'radarr.OpenInstanceDescription'.tr())],
          trailing: LunaIconButton(
            icon: LunaModule.RADARR.icon,
            color: LunaModule.RADARR.color,
          ),
          onTap: () => RadarrRoutes.HOME.goInstance(
            instanceId: instance.id,
            buildTree: true,
          ),
        );
      }).toList(),
    );
  }
}
