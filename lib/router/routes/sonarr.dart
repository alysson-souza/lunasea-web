import 'package:flutter/material.dart';
import 'package:lunasea/api/sonarr/models.dart';
import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/sonarr/core/consolidated_state.dart';
import 'package:lunasea/modules/sonarr/core/state.dart';
import 'package:lunasea/modules/sonarr/routes/add_series/route.dart';
import 'package:lunasea/modules/sonarr/routes/add_series_details/route.dart';
import 'package:lunasea/modules/sonarr/routes/edit_series/route.dart';
import 'package:lunasea/modules/sonarr/routes/history/route.dart';
import 'package:lunasea/modules/sonarr/routes/queue/route.dart';
import 'package:lunasea/modules/sonarr/routes/releases/route.dart';
import 'package:lunasea/modules/sonarr/routes/season_details/route.dart';
import 'package:lunasea/modules/sonarr/routes/series_details/route.dart';
import 'package:lunasea/modules/sonarr/routes/sonarr/consolidated_route.dart';
import 'package:lunasea/modules/sonarr/routes/sonarr/route.dart';
import 'package:lunasea/modules/sonarr/routes/sonarr/widgets/navigation_bar.dart';
import 'package:lunasea/modules/sonarr/routes/tags/route.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/system/state.dart';
import 'package:lunasea/system/stores/backend_stores.dart';
import 'package:lunasea/system/preferences/sonarr.dart';
import 'package:lunasea/vendor.dart';

enum SonarrRoutes with LunaRoutesMixin {
  // Consolidated view — serves as the module root when multiple instances exist
  CONSOLIDATED('/sonarr'),
  // Per-instance view at /sonarr/:instanceId (sub-route of CONSOLIDATED)
  HOME(':instanceId'),
  ADD_SERIES('add_series'),
  ADD_SERIES_DETAILS('details'),
  HISTORY('history'),
  QUEUE('queue'),
  RELEASES('releases'),
  SERIES('series/:series'),
  SERIES_EDIT('edit'),
  SERIES_SEASON('season/:season'),
  TAGS('tags');

  @override
  final String path;

  const SonarrRoutes(this.path);

  @override
  LunaModule get module => LunaModule.SONARR;

  @override
  bool isModuleEnabled(BuildContext context) {
    // For the consolidated route (no instanceId in path), check if any instance
    // is enabled.  Per-instance routes use the same check via the registry.
    final profiles = context.read<ProfilesStore>();
    return profiles.active.enabledInstances(LunaModule.SONARR).isNotEmpty;
  }

  @override
  Widget wrapServiceInstanceRoute(
    BuildContext context,
    GoRouterState state,
    LunaServiceInstance instance,
    Widget child,
  ) {
    final registry = context.read<LunaModuleStateRegistry<SonarrState>>();
    return ChangeNotifierProvider<SonarrState>.value(
      value: registry.get(instance),
      child: child,
    );
  }

  @override
  GoRoute get routes {
    switch (this) {
      case SonarrRoutes.CONSOLIDATED:
        return route(
          builder: (context, state) {
            final profiles = context.read<ProfilesStore>();
            final instances = profiles.active.enabledInstances(
              LunaModule.SONARR,
            );
            final registry = context
                .read<LunaModuleStateRegistry<SonarrState>>();
            final instanceStates = instances
                .map((inst) => registry.get(inst))
                .toList();
            // Provide first instance's SonarrState so existing search/sort/filter
            // widgets that read SonarrState continue to work.
            final sharedState = instanceStates.isNotEmpty
                ? instanceStates.first
                : SonarrState();
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<SonarrConsolidatedState>(
                  create: (_) => SonarrConsolidatedState(
                    instances: instances,
                    instanceStates: instanceStates,
                  ),
                ),
                ChangeNotifierProvider<SonarrState>.value(value: sharedState),
              ],
              child: SonarrConsolidatedRoute(
                initialPage: tabIndexFromRoute(
                  state,
                  SonarrNavigationBar.tabKeys,
                  fallback: SonarrPreferences.NAVIGATION_INDEX.read(),
                ),
              ),
            );
          },
        );
      case SonarrRoutes.HOME:
        return route(
          builder: (context, state) {
            final instance = serviceInstanceFromRoute(
              context,
              state,
              LunaModule.SONARR,
            );
            return SonarrRoute(
              instance: instance!,
              initialPage: tabIndexFromRoute(
                state,
                SonarrNavigationBar.tabKeys,
                fallback: SonarrPreferences.NAVIGATION_INDEX.read(),
              ),
            );
          },
        );
      case SonarrRoutes.ADD_SERIES:
        return route(
          builder: (_, state) {
            final query = state.uri.queryParameters['query'] ?? '';
            return AddSeriesRoute(query: query);
          },
        );
      case SonarrRoutes.ADD_SERIES_DETAILS:
        return route(
          builder: (_, state) {
            final series = state.extra as SonarrSeries?;
            return AddSeriesDetailsRoute(series: series);
          },
        );
      case SonarrRoutes.HISTORY:
        return route(widget: const HistoryRoute());
      case SonarrRoutes.QUEUE:
        return route(widget: const QueueRoute());
      case SonarrRoutes.RELEASES:
        return route(
          builder: (_, state) {
            final episode = int.tryParse(
              state.uri.queryParameters['episode'] ?? '',
            );
            final series = int.tryParse(
              state.uri.queryParameters['series'] ?? '',
            );
            final season = int.tryParse(
              state.uri.queryParameters['season'] ?? '',
            );
            return ReleasesRoute(
              episodeId: episode,
              seriesId: series,
              seasonNumber: season,
            );
          },
        );
      case SonarrRoutes.SERIES:
        return route(
          builder: (_, state) {
            final seriesId =
                int.tryParse(state.pathParameters['series'] ?? '-1') ?? -1;
            return SeriesDetailsRoute(seriesId: seriesId);
          },
        );
      case SonarrRoutes.SERIES_EDIT:
        return route(
          builder: (_, state) {
            final seriesId =
                int.tryParse(state.pathParameters['series'] ?? '-1') ?? -1;
            return SeriesEditRoute(seriesId: seriesId);
          },
        );
      case SonarrRoutes.SERIES_SEASON:
        return route(
          builder: (_, state) {
            final seriesId =
                int.tryParse(state.pathParameters['series'] ?? '-1') ?? -1;
            final season =
                int.tryParse(state.pathParameters['season'] ?? '-1') ?? -1;
            return SeriesSeasonDetailsRoute(
              seriesId: seriesId,
              seasonNumber: season,
            );
          },
        );
      case SonarrRoutes.TAGS:
        return route(widget: const TagsRoute());
    }
  }

  @override
  List<GoRoute> get subroutes {
    switch (this) {
      case SonarrRoutes.CONSOLIDATED:
        // HOME is a sub-route so /sonarr/:instanceId resolves correctly.
        return [SonarrRoutes.HOME.routes];
      case SonarrRoutes.HOME:
        return [
          SonarrRoutes.ADD_SERIES.routes,
          SonarrRoutes.HISTORY.routes,
          SonarrRoutes.QUEUE.routes,
          SonarrRoutes.RELEASES.routes,
          SonarrRoutes.SERIES.routes,
          SonarrRoutes.TAGS.routes,
        ];
      case SonarrRoutes.ADD_SERIES:
        return [SonarrRoutes.ADD_SERIES_DETAILS.routes];
      case SonarrRoutes.SERIES:
        return [
          SonarrRoutes.SERIES_EDIT.routes,
          SonarrRoutes.SERIES_SEASON.routes,
        ];
      default:
        return const [];
    }
  }
}
