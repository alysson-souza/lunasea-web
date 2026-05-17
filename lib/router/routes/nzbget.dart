import 'package:flutter/material.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/nzbget/core/state.dart';
import 'package:lunasea/modules/nzbget/routes/nzbget.dart';
import 'package:lunasea/modules/nzbget/routes/statistics.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/vendor.dart';

enum NZBGetRoutes with LunaRoutesMixin {
  HOME('/nzbget/:instanceId'),
  STATISTICS('statistics');

  @override
  final String path;

  const NZBGetRoutes(this.path);

  @override
  LunaModule get module => LunaModule.NZBGET;

  @override
  bool isModuleEnabled(BuildContext context) => true;

  @override
  Widget wrapServiceInstanceRoute(
    BuildContext context,
    GoRouterState state,
    LunaServiceInstance instance,
    Widget child,
  ) {
    final registry = context.read<LunaModuleStateRegistry<NZBGetState>>();
    return ChangeNotifierProvider<NZBGetState>.value(
      value: registry.get(instance),
      child: child,
    );
  }

  @override
  GoRoute get routes {
    switch (this) {
      case NZBGetRoutes.HOME:
        return route(
          builder: (context, state) {
            final instance = serviceInstanceFromRoute(
              context,
              state,
              LunaModule.NZBGET,
            );
            return NZBGetRoute(instance: instance!);
          },
        );
      case NZBGetRoutes.STATISTICS:
        return route(
          builder: (context, state) {
            final instance = serviceInstanceFromRoute(
              context,
              state,
              LunaModule.NZBGET,
            );
            return StatisticsRoute(instance: instance);
          },
        );
    }
  }

  @override
  List<GoRoute> get subroutes {
    switch (this) {
      case NZBGetRoutes.HOME:
        return [NZBGetRoutes.STATISTICS.routes];
      default:
        return const [];
    }
  }
}
