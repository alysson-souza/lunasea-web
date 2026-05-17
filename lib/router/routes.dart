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
  radarr('radarr', root: RadarrRoutes.HOME),
  sabnzbd('sabnzbd', root: SABnzbdRoutes.HOME),
  search('search', root: SearchRoutes.HOME),
  settings('settings', root: SettingsRoutes.HOME),
  sonarr('sonarr', root: SonarrRoutes.HOME),
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
    bool buildTree = false,
  }) {
    final pathParams = _withCurrentInstance(params);
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
        params.containsKey('instanceId')) {
      return params;
    }
    final selectedInstanceId = currentInstanceId(routeModule);
    if (selectedInstanceId == null || selectedInstanceId.isEmpty) return params;
    return <String, String>{...params, 'instanceId': selectedInstanceId};
  }

  void goInstance({
    required String instanceId,
    Object? extra,
    Map<String, String> params = const <String, String>{},
    Map<String, String> queryParams = const <String, String>{},
    bool buildTree = false,
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
    if (instance.id == instanceId && instance.enabled) return instance;
  }
  return null;
}

String? currentInstanceId(LunaModule module) {
  try {
    final segments =
        LunaRouter.router.routeInformationProvider.value.uri.pathSegments;
    if (segments.length < 2 || segments.first != module.key) return null;
    return segments[1];
  } on Object {
    return null;
  }
}
