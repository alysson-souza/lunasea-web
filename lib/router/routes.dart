import 'package:flutter/material.dart';

import 'package:lunasea/database/models/profile.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/router/router.dart';
import 'package:lunasea/router/routes/bios.dart';
import 'package:lunasea/router/routes/dashboard.dart';
import 'package:lunasea/router/routes/external_modules.dart';
import 'package:lunasea/router/routes/lidarr.dart';
import 'package:lunasea/router/routes/nzbget.dart';
import 'package:lunasea/router/routes/radarr.dart';
import 'package:lunasea/router/routes/sabnzbd.dart';
import 'package:lunasea/router/routes/search.dart';
import 'package:lunasea/router/routes/settings.dart';
import 'package:lunasea/router/routes/sonarr.dart';
import 'package:lunasea/router/routes/tautulli.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/vendor.dart';
import 'package:lunasea/widgets/pages/instance_not_configured.dart';
import 'package:lunasea/widgets/pages/not_enabled.dart';

enum LunaRoutes {
  bios('bios', root: BIOSRoutes.HOME),
  dashboard('dashboard', root: DashboardRoutes.HOME),
  externalModules('external_modules', root: ExternalModulesRoutes.HOME),
  lidarr('lidarr', root: LidarrRoutes.HOME),
  nzbget('nzbget', root: NZBGetRoutes.HOME),
  radarr('radarr', root: RadarrRoutes.CONSOLIDATED),
  sabnzbd('sabnzbd', root: SABnzbdRoutes.HOME),
  search('search', root: SearchRoutes.HOME),
  settings('settings', root: SettingsRoutes.HOME),
  sonarr('sonarr', root: SonarrRoutes.CONSOLIDATED),
  tautulli('tautulli', root: TautulliRoutes.HOME);

  final String key;
  final LunaRoutesMixin root;

  const LunaRoutes(this.key, {required this.root});

  static String get initialLocation => BIOSRoutes.HOME.path;
}

mixin LunaRoutesMixin on Enum {
  String get _routeName => '${this.module?.key ?? 'unknown'}:$name';

  String get path;
  LunaModule? get module;

  GoRoute get routes;
  List<GoRoute> get subroutes => const <GoRoute>[];

  bool isModuleEnabled(BuildContext context);

  Widget wrapServiceInstanceRoute(
    BuildContext context,
    GoRouterState state,
    LunaServiceInstance instance,
    Widget child,
  ) {
    return child;
  }

  GoRoute route({
    Widget? widget,
    Widget Function(BuildContext, GoRouterState)? builder,
  }) {
    assert(!(widget == null && builder == null));
    return GoRoute(
      path: path,
      name: _routeName,
      routes: subroutes,
      builder: (context, state) {
        final routeModule = module;
        if (routeModule != null &&
            routeModule.supportsServiceInstances &&
            state.pathParameters.containsKey('instanceId')) {
          final selectedInstanceId = instanceId(state);
          final configured = serviceInstanceFromRoute(
            context,
            state,
            routeModule,
          );
          if (configured != null) {
            // Remember the instance this route resolved to. Imperative pushes
            // (used by all in-module drill-downs) do not update the browser
            // URL in go_router 14. The route's own builder state can recover
            // the instance, so cache it here for `currentInstanceId` to reuse
            // on subsequent `.go()` navigations.
            _activeInstanceIds[routeModule.key] = configured.id;
            return wrapServiceInstanceRoute(
              context,
              state,
              configured,
              builder?.call(context, state) ?? widget!,
            );
          }
          return InstanceNotConfiguredPage(
            module: routeModule,
            instanceId: selectedInstanceId,
          );
        }
        // NOTE: we intentionally do NOT clear `_activeInstanceIds` here. The
        // consolidated (no-instanceId) base route is rebuilt by go_router on
        // every imperative push — including AFTER the pushed instance route's
        // builder runs — so clearing here would wipe the instance we just
        // cached. Consolidated-level widgets always navigate with an explicit
        // `goInstance`, so a lingering cached id is never consulted there.
        if (isModuleEnabled(context)) {
          return builder?.call(context, state) ?? widget!;
        }
        return NotEnabledPage(module: module?.title ?? 'LunaSea');
      },
    );
  }

  GoRoute redirect({required GoRouterRedirect redirect}) {
    return GoRoute(path: path, name: _routeName, redirect: redirect);
  }

  void go({
    Object? extra,
    Map<String, String> params = const <String, String>{},
    Map<String, String> queryParams = const <String, String>{},
    bool buildTree = true,
  }) {
    final pathParams = _withCurrentInstance(params);
    final routeModule = module;
    if (buildTree &&
        routeModule != null &&
        routeModule.supportsServiceInstances &&
        !pathParams.containsKey('instanceId') &&
        !path.contains(':instanceId')) {
      _activeInstanceIds.remove(routeModule.key);
    }
    if (buildTree) {
      return LunaRouter.router.goNamed(
        _routeName,
        extra: extra,
        pathParameters: pathParams,
        queryParameters: queryParams,
      );
    }
    LunaRouter.router.pushNamed(
      _routeName,
      extra: extra,
      pathParameters: pathParams,
      queryParameters: queryParams,
    );
  }

  Map<String, String> _withCurrentInstance(Map<String, String> params) {
    final routeModule = module;
    if (routeModule == null ||
        !routeModule.supportsServiceInstances ||
        _isModuleRootWithoutInstance(routeModule) ||
        params.containsKey('instanceId')) {
      return params;
    }
    final selectedInstanceId = currentInstanceId(routeModule);
    if (selectedInstanceId == null || selectedInstanceId.isEmpty) return params;
    return <String, String>{...params, 'instanceId': selectedInstanceId};
  }

  bool _isModuleRootWithoutInstance(LunaModule routeModule) {
    return path == '/${routeModule.key}';
  }

  void goInstance({
    required String instanceId,
    Object? extra,
    Map<String, String> params = const <String, String>{},
    Map<String, String> queryParams = const <String, String>{},
    bool buildTree = true,
  }) {
    go(
      extra: extra,
      params: <String, String>{...params, 'instanceId': instanceId},
      queryParams: queryParams,
      buildTree: buildTree,
    );
  }
}

String instanceId(GoRouterState state) {
  return state.pathParameters['instanceId'] ?? '';
}

LunaServiceInstance? serviceInstanceFromRoute(
  BuildContext context,
  GoRouterState state,
  LunaModule module,
) {
  return serviceInstanceFromProfile(
    state.pathParameters['instanceId'],
    context.read<ProfilesStore>().active,
    module,
  );
}

LunaServiceInstance? serviceInstanceFromProfile(
  String? instanceId,
  LunaProfile profile,
  LunaModule module,
) {
  if (instanceId == null) return null;
  for (final instance in profile.instancesFor(module)) {
    if (instance.id == instanceId &&
        instance.enabled &&
        instance.host.isNotEmpty)
      return instance;
  }
  return null;
}

/// The instance id each instance-aware module's currently-displayed route
/// resolved to, keyed by [LunaModule.key]. Maintained by the route builder in
/// [LunaRoutesMixin.route] - see the comment there for why this is needed
/// instead of reading the URL or `GoRouter.state`.
final Map<String, String> _activeInstanceIds = <String, String>{};

@visibleForTesting
void debugRememberCurrentInstanceIdForTesting(
  LunaModule module,
  String instanceId,
) {
  _activeInstanceIds[module.key] = instanceId;
}

@visibleForTesting
void debugClearCurrentInstanceIdsForTesting() {
  _activeInstanceIds.clear();
}

String? currentInstanceId(LunaModule module) {
  try {
    final state = LunaRouter.router.state;
    final fullPath = state.fullPath;
    if (fullPath != null && fullPath.startsWith('/${module.key}')) {
      final id = state.pathParameters['instanceId'];
      if (id != null && id.isNotEmpty) return id;
      if (!fullPath.contains(':instanceId')) {
        _activeInstanceIds.remove(module.key);
        return null;
      }
    } else if (fullPath != null) {
      return null;
    }
  } on Object {
    // Fall back to the route-builder cache and address-bar parsing below.
  }

  // Primary: the instance the current route resolved to. This is correct even
  // when the route was reached via an imperative `push` (which leaves the
  // address-bar URL at the consolidated root, e.g. `/sonarr`).
  final cached = _activeInstanceIds[module.key];
  if (cached != null && cached.isNotEmpty) return cached;
  // Fallback: parse the address-bar URL (covers the very first build before any
  // instance route has rendered, and direct deep-links).
  try {
    final segments =
        LunaRouter.router.routeInformationProvider.value.uri.pathSegments;
    if (segments.length < 2 || segments.first != module.key) return null;
    return segments[1];
  } on Object {
    return null;
  }
}

int tabIndexFromRoute(
  GoRouterState state,
  List<String> tabs, {
  required int fallback,
}) {
  final tab = state.uri.queryParameters['tab'];
  if (tab == null) return fallback;
  final index = tabs.indexOf(tab);
  if (index == -1) return fallback;
  return index;
}
