import 'package:flutter/material.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/history.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/routes/history_stages.dart';
import 'package:lunasea/modules/sabnzbd/routes/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/routes/statistics.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/vendor.dart';

enum SABnzbdRoutes with LunaRoutesMixin {
  HOME('/sabnzbd/:instanceId'),
  STATISTICS('statistics'),
  HISTORY_STAGES('history/stages');

  @override
  final String path;

  const SABnzbdRoutes(this.path);

  @override
  LunaModule get module => LunaModule.SABNZBD;

  @override
  bool isModuleEnabled(BuildContext context) => true;

  @override
  Widget wrapServiceInstanceRoute(
    BuildContext context,
    GoRouterState state,
    LunaServiceInstance instance,
    Widget child,
  ) {
    final registry = context.read<LunaModuleStateRegistry<SABnzbdState>>();
    return ChangeNotifierProvider<SABnzbdState>.value(
      value: registry.get(instance),
      child: child,
    );
  }

  @override
  GoRoute get routes {
    switch (this) {
      case SABnzbdRoutes.HOME:
        return route(
          builder: (context, state) {
            final instance = serviceInstanceFromRoute(
              context,
              state,
              LunaModule.SABNZBD,
            );
            return SABnzbdRoute(instance: instance!);
          },
        );
      case SABnzbdRoutes.STATISTICS:
        return route(
          builder: (context, state) {
            final instance = serviceInstanceFromRoute(
              context,
              state,
              LunaModule.SABNZBD,
            );
            return StatisticsRoute(instance: instance);
          },
        );
      case SABnzbdRoutes.HISTORY_STAGES:
        return route(
          builder: (_, state) {
            final history = state.extra as SABnzbdHistoryData?;
            return HistoryStagesRoute(history: history);
          },
        );
    }
  }

  @override
  List<GoRoute> get subroutes {
    switch (this) {
      case SABnzbdRoutes.HOME:
        return [
          SABnzbdRoutes.STATISTICS.routes,
          SABnzbdRoutes.HISTORY_STAGES.routes,
        ];
      default:
        return const [];
    }
  }
}
