import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';

/// Catalogue tab for the consolidated Sonarr view.
///
/// Merges the series libraries of all enabled Sonarr instances.  Each tile
/// carries a source-instance label and navigates via [goInstance].
class SonarrConsolidatedCatalogueRoute extends StatefulWidget {
  const SonarrConsolidatedCatalogueRoute({super.key});

  @override
  State<SonarrConsolidatedCatalogueRoute> createState() => _State();
}

class _State extends State<SonarrConsolidatedCatalogueRoute>
    with AutomaticKeepAliveClientMixin {
  static final _itemExtentWithLabel = LunaBlock.calculateItemExtent(4);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final consolidated = context.read<SonarrConsolidatedState>();
    consolidated.fetchAll();
    if (consolidated.series != null &&
        consolidated.qualityProfilesByInstance != null) {
      await Future.wait([
        consolidated.series!,
        consolidated.qualityProfilesByInstance!,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      module: LunaModule.SONARR,
      body: _body(),
      appBar: _appBar(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar.empty(
      child: SonarrSeriesSearchBar(
        scrollController: SonarrNavigationBar.scrollControllers[0],
      ),
      height: LunaTextInputBar.defaultAppBarHeight,
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
              Future<List<LunaConsolidatedItem<SonarrSeries>>>?,
              Future<Map<String, List<SonarrQualityProfile>>>?
            >
          >(
            selector: (_, s) => Tuple2(s.series, s.qualityProfilesByInstance),
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
                        'Unable to fetch consolidated Sonarr series',
                        snapshot.error,
                        snapshot.stackTrace,
                      );
                    }
                    return LunaMessage.error(
                      onTap: _refreshKey.currentState!.show,
                    );
                  }
                  if (snapshot.hasData) {
                    return _seriesList(
                      snapshot.data![0]
                          as List<LunaConsolidatedItem<SonarrSeries>>,
                      snapshot.data![1]
                          as Map<String, List<SonarrQualityProfile>>,
                    );
                  }
                  return const LunaLoader();
                },
              );
            },
          ),
    );
  }

  List<LunaConsolidatedItem<SonarrSeries>> _filterAndSort(
    List<LunaConsolidatedItem<SonarrSeries>> items,
    String query,
    SonarrSeriesSorting sorting,
    SonarrSeriesFilter filter,
    bool ascending,
  ) {
    if (items.isEmpty) return items;

    // Build identity map for reverse lookup after sort.
    final lookup = <SonarrSeries, LunaConsolidatedItem<SonarrSeries>>{};
    for (final ci in items) {
      lookup[ci.item] = ci;
    }

    var series = items
        .where((ci) {
          if (ci.item.id == null) return false;
          if (query.isNotEmpty) {
            return ci.item.title!.toLowerCase().contains(query.toLowerCase());
          }
          return true;
        })
        .map((ci) => ci.item)
        .toList();

    series = filter.filter(series);
    series = sorting.sort(series, ascending);

    return series
        .map((s) => lookup[s])
        .whereType<LunaConsolidatedItem<SonarrSeries>>()
        .toList();
  }

  Widget _seriesList(
    List<LunaConsolidatedItem<SonarrSeries>> items,
    Map<String, List<SonarrQualityProfile>> profilesByInstance,
  ) {
    if (items.isEmpty) {
      return LunaMessage(
        text: 'sonarr.NoSeriesFound'.tr(),
        buttonText: 'lunasea.Refresh'.tr(),
        onTap: _refreshKey.currentState!.show,
      );
    }

    final consolidated = context.watch<SonarrConsolidatedState>();
    final showInstanceLabel = consolidated.instances.length > 1;
    final registry = context.read<LunaModuleStateRegistry<SonarrState>>();

    return Selector<
      SonarrState,
      Tuple4<String, SonarrSeriesSorting, SonarrSeriesFilter, bool>
    >(
      selector: (_, state) => Tuple4(
        state.seriesSearchQuery,
        state.seriesSortType,
        state.seriesFilterType,
        state.seriesSortAscending,
      ),
      builder: (context, controls, _) {
        final filtered = _filterAndSort(
          items,
          controls.item1,
          controls.item2,
          controls.item3,
          controls.item4,
        );
        if (filtered.isEmpty) {
          return LunaListView(
            controller: SonarrNavigationBar.scrollControllers[0],
            children: [LunaMessage.inList(text: 'sonarr.NoSeriesFound'.tr())],
          );
        }

        final itemExtent = showInstanceLabel
            ? _itemExtentWithLabel
            : SonarrSeriesTile.itemExtent;

        return LunaListViewBuilder(
          controller: SonarrNavigationBar.scrollControllers[0],
          itemCount: filtered.length,
          itemExtent: itemExtent,
          itemBuilder: (context, index) {
            final ci = filtered[index];
            final instanceState = registry.get(ci.instance);
            final profiles =
                profilesByInstance[ci.instance.ref.key] ?? const [];
            final profile = profiles.firstWhereOrNull(
              (p) => p.id == ci.item.qualityProfileId,
            );
            return ChangeNotifierProvider<SonarrState>.value(
              value: instanceState,
              child: SonarrSeriesTile(
                series: ci.item,
                profile: profile,
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
            );
          },
        );
      },
    );
  }
}
