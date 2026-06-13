import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';

/// Missing tab for the consolidated Sonarr view.
///
/// Merges the missing/wanted episodes from all enabled Sonarr instances.
class SonarrConsolidatedMissingRoute extends StatefulWidget {
  const SonarrConsolidatedMissingRoute({super.key});

  @override
  State<SonarrConsolidatedMissingRoute> createState() => _State();
}

class _State extends State<SonarrConsolidatedMissingRoute>
    with AutomaticKeepAliveClientMixin {
  static final _itemExtentWithLabel = LunaBlock.calculateItemExtent(4);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  Future<List<Object>>? _mergedFuture;
  Future<List<LunaConsolidatedItem<SonarrMissingRecord>>>? _missingFuture;
  Future<List<LunaConsolidatedItem<SonarrSeries>>>? _seriesFuture;

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final consolidated = context.read<SonarrConsolidatedState>();
    consolidated.fetchAll();
    await Future.wait([
      if (consolidated.missing != null) consolidated.missing!,
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
              Future<List<LunaConsolidatedItem<SonarrMissingRecord>>>?,
              Future<List<LunaConsolidatedItem<SonarrSeries>>>?
            >
          >(
            selector: (_, s) => Tuple2(s.missing, s.series),
            builder: (context, tuple, _) {
              final future = _mergeFuture(tuple.item1, tuple.item2);
              if (future == null) return const LunaLoader();
              return FutureBuilder(
                future: future,
                builder: (context, AsyncSnapshot<List<Object>> snapshot) {
                  if (snapshot.hasError) {
                    if (snapshot.connectionState != ConnectionState.waiting) {
                      LunaLogger().error(
                        'Unable to fetch consolidated Sonarr missing episodes',
                        snapshot.error,
                        snapshot.stackTrace,
                      );
                    }
                    return LunaMessage.error(
                      onTap: _refreshKey.currentState!.show,
                    );
                  }
                  if (snapshot.hasData) {
                    final missing =
                        snapshot.data![0]
                            as List<LunaConsolidatedItem<SonarrMissingRecord>>;
                    final allSeries =
                        snapshot.data![1]
                            as List<LunaConsolidatedItem<SonarrSeries>>;
                    final seriesMap = <String, Map<int, SonarrSeries>>{};
                    for (final cs in allSeries) {
                      final key = cs.instance.ref.key;
                      seriesMap.putIfAbsent(key, () => {});
                      if (cs.item.id != null) {
                        seriesMap[key]![cs.item.id!] = cs.item;
                      }
                    }
                    return _episodes(missing, seriesMap);
                  }
                  return const LunaLoader();
                },
              );
            },
          ),
    );
  }

  Future<List<Object>>? _mergeFuture(
    Future<List<LunaConsolidatedItem<SonarrMissingRecord>>>? missing,
    Future<List<LunaConsolidatedItem<SonarrSeries>>>? series,
  ) {
    if (missing == null || series == null) return null;
    if (missing == _missingFuture && series == _seriesFuture) {
      return _mergedFuture;
    }
    _missingFuture = missing;
    _seriesFuture = series;
    return _mergedFuture = Future.wait([missing, series]);
  }

  Widget _episodes(
    List<LunaConsolidatedItem<SonarrMissingRecord>> missing,
    Map<String, Map<int, SonarrSeries>> seriesMap,
  ) {
    if (missing.isEmpty) {
      return LunaMessage(
        text: 'sonarr.NoEpisodesFound'.tr(),
        buttonText: 'lunasea.Refresh'.tr(),
        onTap: _refreshKey.currentState?.show,
      );
    }

    final consolidated = context.read<SonarrConsolidatedState>();
    final showInstanceLabel = consolidated.instances.length > 1;
    final registry = context.read<LunaModuleStateRegistry<SonarrState>>();
    final itemExtent = showInstanceLabel
        ? _itemExtentWithLabel
        : SonarrMissingTile.itemExtent;

    return LunaListViewBuilder(
      controller: SonarrNavigationBar.scrollControllers[2],
      itemCount: missing.length,
      itemExtent: itemExtent,
      itemBuilder: (context, index) {
        final ci = missing[index];
        final instanceState = registry.get(ci.instance);
        final series = seriesMap[ci.instance.ref.key]?[ci.item.seriesId];
        return ChangeNotifierProvider<SonarrState>.value(
          value: instanceState,
          child: SonarrMissingTile(
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
        );
      },
    );
  }
}
