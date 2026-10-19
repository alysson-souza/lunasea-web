import 'package:flutter/material.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sabnzbd/core/api/data/history.dart';
import 'package:lunasea/modules/sabnzbd/core/history_location.dart';
import 'package:lunasea/modules/sabnzbd/core/state.dart';
import 'package:lunasea/modules/sabnzbd/routes/consolidated.dart';
import 'package:lunasea/modules/sabnzbd/routes/history_stages.dart';
import 'package:lunasea/modules/sabnzbd/routes/sabnzbd.dart';
import 'package:lunasea/modules/sabnzbd/routes/statistics.dart';
import 'package:lunasea/modules/sabnzbd/widgets/navigation_bar.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/preferences/sabnzbd.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';

enum SABnzbdRoutes with LunaRoutesMixin {
  CONSOLIDATED('/sabnzbd'),
  HOME(':instanceId'),
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
  GoRoute route({
    Widget? widget,
    Widget Function(BuildContext, GoRouterState)? builder,
  }) {
    final configuredRoute = super.route(widget: widget, builder: builder);
    return GoRoute(
      path: configuredRoute.path,
      name: configuredRoute.name,
      routes: configuredRoute.routes,
      pageBuilder:
          this == SABnzbdRoutes.CONSOLIDATED || this == SABnzbdRoutes.HOME
          ? (context, state) => NoTransitionPage<void>(
              key: state.pageKey,
              child: _SABnzbdReactiveRoute(
                route: this,
                routeState: state,
                builder: configuredRoute.builder!,
              ),
            )
          : null,
      builder: this == SABnzbdRoutes.CONSOLIDATED || this == SABnzbdRoutes.HOME
          ? null
          : (context, state) => _SABnzbdReactiveRoute(
              route: this,
              routeState: state,
              builder: configuredRoute.builder!,
            ),
    );
  }

  @override
  Widget wrapServiceInstanceRoute(
    BuildContext context,
    GoRouterState state,
    LunaServiceInstance instance,
    Widget child,
  ) {
    final registry = context.read<LunaModuleStateRegistry<SABnzbdState>>();
    final source = registry.get(instance);
    return ChangeNotifierProvider<SABnzbdState>.value(
      key: ObjectKey(source),
      value: source,
      child: child,
    );
  }

  @override
  GoRoute get routes {
    switch (this) {
      case SABnzbdRoutes.CONSOLIDATED:
        return route(
          builder: (context, state) => SABnzbdConsolidatedRoute(
            initialPage: tabIndexFromRoute(
              state,
              SABnzbdNavigationBar.tabKeys,
              fallback: SABnzbdPreferences.NAVIGATION_INDEX.read(),
            ),
          ),
        );
      case SABnzbdRoutes.HOME:
        return route(
          builder: (context, state) {
            final instance = serviceInstanceFromRoute(
              context,
              state,
              LunaModule.SABNZBD,
            );
            return SABnzbdRoute(
              instance: instance!,
              initialPage: tabIndexFromRoute(
                state,
                SABnzbdNavigationBar.tabKeys,
                fallback: SABnzbdPreferences.NAVIGATION_INDEX.read(),
              ),
            );
          },
        );
      case SABnzbdRoutes.STATISTICS:
        return route(builder: (_, __) => const StatisticsRoute());
      case SABnzbdRoutes.HISTORY_STAGES:
        return route(
          builder: (context, state) {
            final location = SABnzbdHistoryLocation.fromQuery(
              state.uri.queryParameters,
            );
            final owner = serviceInstanceFromRoute(
              context,
              state,
              LunaModule.SABNZBD,
            );
            final valid =
                _SABnzbdHistoryOwnerScope.of(context) &&
                location != null &&
                owner != null &&
                location.matches(
                  owner,
                  context.read<ProfilesStore>().activeProfile,
                );
            final extra = state.extra;
            return HistoryStagesRoute(
              key: ValueKey('${state.uri}:$valid'),
              location: valid ? location : null,
              history:
                  valid &&
                      extra is SABnzbdHistoryData &&
                      extra.nzoId == location.nzoId
                  ? extra
                  : null,
            );
          },
        );
    }
  }

  @override
  List<GoRoute> get subroutes {
    switch (this) {
      case SABnzbdRoutes.CONSOLIDATED:
        return [SABnzbdRoutes.HOME.routes];
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

class _SABnzbdReactiveRoute extends StatefulWidget {
  final SABnzbdRoutes route;
  final GoRouterState routeState;
  final Widget Function(BuildContext, GoRouterState) builder;

  const _SABnzbdReactiveRoute({
    required this.route,
    required this.routeState,
    required this.builder,
  });

  @override
  State<_SABnzbdReactiveRoute> createState() => _SABnzbdReactiveRouteState();
}

class _SABnzbdReactiveRouteState extends State<_SABnzbdReactiveRoute> {
  SABnzbdState? _historyOwner;
  bool _historyOwnerCaptured = false;
  bool _historyOwnerInvalidated = false;

  @override
  void didUpdateWidget(covariant _SABnzbdReactiveRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeState.uri != widget.routeState.uri ||
        !identical(oldWidget.routeState.extra, widget.routeState.extra)) {
      _historyOwner = null;
      _historyOwnerCaptured = false;
      _historyOwnerInvalidated = false;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => Consumer2<ProfilesStore, LunaModuleStateRegistry<SABnzbdState>>(
    builder: (context, profiles, registry, _) {
      if (widget.route == SABnzbdRoutes.HISTORY_STAGES) {
        final instance = serviceInstanceFromProfile(
          instanceId(widget.routeState),
          profiles.active,
          LunaModule.SABNZBD,
        );
        final owner = instance == null ? null : registry.get(instance);
        if (!_historyOwnerCaptured) {
          _historyOwner = owner;
          _historyOwnerCaptured = true;
        } else if (!identical(owner, _historyOwner)) {
          // State identity includes the profile ref and full configuration.
          // Keep invalidation even if the original profile is selected again.
          _historyOwnerInvalidated = true;
        }
      }
      return _SABnzbdHistoryOwnerScope(
        valid: !_historyOwnerInvalidated,
        child: Builder(
          builder: (context) => widget.builder(context, widget.routeState),
        ),
      );
    },
  );
}

class _SABnzbdHistoryOwnerScope extends InheritedWidget {
  final bool valid;

  const _SABnzbdHistoryOwnerScope({required this.valid, required super.child});

  static bool of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SABnzbdHistoryOwnerScope>()!
      .valid;

  @override
  bool updateShouldNotify(_SABnzbdHistoryOwnerScope oldWidget) =>
      valid != oldWidget.valid;
}
