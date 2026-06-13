import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';

/// Upcoming tab for the consolidated Sonarr view.
///
/// Merges upcoming episodes from all enabled Sonarr instances. Each day bucket
/// shows tiles tagged with the source-instance label.
class SonarrConsolidatedUpcomingRoute extends StatefulWidget {
  const SonarrConsolidatedUpcomingRoute({super.key});

  @override
  State<SonarrConsolidatedUpcomingRoute> createState() => _State();
}

class _State extends State<SonarrConsolidatedUpcomingRoute>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final consolidated = context.read<SonarrConsolidatedState>();
    consolidated.fetchAll();
    await Future.wait([
      if (consolidated.upcoming != null) consolidated.upcoming!,
      if (consolidated.series != null) consolidated.series!,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      module: LunaModule.SONARR,
      body: _body(),
    );
  }

  Widget _body() {
    return LunaRefreshIndicator(
      context: context,
      key: _refreshKey,
      onRefresh: _refresh,
      child:
          Selector<
            SonarrConsolidatedState,
            Tuple2<
              Future<List<LunaConsolidatedItem<SonarrCalendar>>>?,
              Future<List<LunaConsolidatedItem<SonarrSeries>>>?
            >
          >(
            selector: (_, s) => Tuple2(s.upcoming, s.series),
            builder: (context, tuple, _) {
              if (tuple.item1 == null || tuple.item2 == null) {
                return const LunaLoader();
              }
              return FutureBuilder(
                future: Future.wait([tuple.item1!, tuple.item2!]),
                builder: (context, AsyncSnapshot<List<Object>> snapshot) {
                  if (snapshot.hasError) {
                    if (snapshot.connectionState != ConnectionState.waiting) {
                      LunaLogger().error(
                        'Unable to fetch consolidated Sonarr upcoming',
                        snapshot.error,
                        snapshot.stackTrace,
                      );
                    }
                    return LunaMessage.error(
                      onTap: _refreshKey.currentState!.show,
                    );
                  }
                  if (snapshot.hasData) {
                    final upcoming =
                        snapshot.data![0]
                            as List<LunaConsolidatedItem<SonarrCalendar>>;
                    final allSeries =
                        snapshot.data![1]
                            as List<LunaConsolidatedItem<SonarrSeries>>;
                    // Build a lookup: instanceKey -> Map<seriesId, SonarrSeries>
                    final seriesMap = <String, Map<int, SonarrSeries>>{};
                    for (final cs in allSeries) {
                      final key = cs.instance.ref.key;
                      seriesMap.putIfAbsent(key, () => {});
                      if (cs.item.id != null) {
                        seriesMap[key]![cs.item.id!] = cs.item;
                      }
                    }
                    return _buildEpisodeList(upcoming, seriesMap);
                  }
                  return const LunaLoader();
                },
              );
            },
          ),
    );
  }

  Widget _buildEpisodeList(
    List<LunaConsolidatedItem<SonarrCalendar>> upcoming,
    Map<String, Map<int, SonarrSeries>> seriesMap,
  ) {
    if (upcoming.isEmpty) {
      return LunaMessage(
        text: 'sonarr.NoEpisodesFound'.tr(),
        buttonText: 'lunasea.Refresh'.tr(),
        onTap: _refreshKey.currentState?.show,
      );
    }

    final consolidated = context.read<SonarrConsolidatedState>();
    final showInstanceLabel = consolidated.instances.length > 1;
    final registry = context.read<LunaModuleStateRegistry<SonarrState>>();

    final episodeMap = <String, _EpisodeDateBucket>{};
    for (final ci in upcoming) {
      if (ci.item.airDateUtc == null) continue;
      final date = DateFormat('y-MM-dd').format(ci.item.airDateUtc!.toLocal());
      episodeMap
          .putIfAbsent(
            date,
            () => _EpisodeDateBucket(
              label: DateFormat(
                'EEEE / MMMM dd, y',
              ).format(ci.item.airDateUtc!.toLocal()),
            ),
          )
          .entries
          .add(ci);
    }

    final List<Widget> widgets = [];
    final sortedDates = episodeMap.keys.toList()..sort();
    for (final dateKey in sortedDates) {
      final bucket = episodeMap[dateKey]!;
      widgets.add(LunaHeader(text: bucket.label));
      for (final ci in bucket.entries) {
        final instKey = ci.instance.ref.key;
        final series = seriesMap[instKey]?[ci.item.seriesId];
        final instanceState = registry.get(ci.instance);
        widgets.add(
          ChangeNotifierProvider<SonarrState>.value(
            value: instanceState,
            child: SonarrUpcomingTile(
              record: ci.item,
              series: series,
              instanceId: ci.instance.id,
              instanceLabel: showInstanceLabel
                  ? TextSpan(
                      text: ci.instance.displayName,
                      style: TextStyle(
                        color: LunaModule.SONARR.color.withValues(alpha: 0.8),
                        fontWeight: LunaUI.FONT_WEIGHT_BOLD,
                        fontSize: LunaUI.FONT_SIZE_H3,
                      ),
                    )
                  : null,
            ),
          ),
        );
      }
    }

    return LunaListView(
      controller: SonarrNavigationBar.scrollControllers[1],
      children: widgets,
    );
  }
}

class _EpisodeDateBucket {
  final String label;
  final List<LunaConsolidatedItem<SonarrCalendar>> entries = [];

  _EpisodeDateBucket({required this.label});
}
