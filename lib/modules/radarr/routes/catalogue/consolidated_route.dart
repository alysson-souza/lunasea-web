import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';

/// Catalogue tab for the consolidated Radarr view.
///
/// Merges the movie libraries of all enabled Radarr instances.  Each tile
/// carries a source-instance label and navigates via [goInstance] so that
/// detail screens resolve correctly without an instanceId in the URL.
///
/// Sort/filter/search UI widgets read from the ambient [RadarrState]
/// (the first instance's state, provided by [RadarrConsolidatedRoute]) so
/// they continue to work without modification.
class RadarrConsolidatedCatalogueRoute extends StatefulWidget {
  const RadarrConsolidatedCatalogueRoute({super.key});

  @override
  State<RadarrConsolidatedCatalogueRoute> createState() => _State();
}

class _State extends State<RadarrConsolidatedCatalogueRoute>
    with AutomaticKeepAliveClientMixin {
  static final _itemExtentWithLabel = LunaBlock.calculateItemExtent(
    3,
    hasBottom: true,
  );

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final consolidated = context.read<RadarrConsolidatedState>();
    consolidated.fetchAll();
    if (consolidated.movies != null &&
        consolidated.qualityProfilesByInstance != null) {
      await Future.wait([
        consolidated.movies!,
        consolidated.qualityProfilesByInstance!,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      body: _body(),
      appBar: _appBar(),
    );
  }

  PreferredSizeWidget _appBar() {
    return LunaAppBar.empty(
      child: RadarrCatalogueSearchBar(
        scrollController: RadarrNavigationBar.scrollControllers[0],
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
            RadarrConsolidatedState,
            Tuple2<
              Future<List<LunaConsolidatedItem<RadarrMovie>>>?,
              Future<Map<String, List<RadarrQualityProfile>>>?
            >
          >(
            selector: (_, s) => Tuple2(s.movies, s.qualityProfilesByInstance),
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
                        'Unable to fetch consolidated Radarr movies',
                        snapshot.error,
                        snapshot.stackTrace,
                      );
                    }
                    return LunaMessage.error(
                      onTap: _refreshKey.currentState!.show,
                    );
                  }
                  if (snapshot.hasData) {
                    return _movieList(
                      snapshot.data![0]
                          as List<LunaConsolidatedItem<RadarrMovie>>,
                      snapshot.data![1]
                          as Map<String, List<RadarrQualityProfile>>,
                    );
                  }
                  return const LunaLoader();
                },
              );
            },
          ),
    );
  }

  List<LunaConsolidatedItem<RadarrMovie>> _filterAndSort(
    List<LunaConsolidatedItem<RadarrMovie>> items,
    String query,
    RadarrMoviesSorting sorting,
    RadarrMoviesFilter filter,
    bool ascending,
  ) {
    if (items.isEmpty) return items;

    // Build an identity map so we can reconstruct consolidated items after sort.
    final lookup = <RadarrMovie, LunaConsolidatedItem<RadarrMovie>>{};
    for (final ci in items) {
      lookup[ci.item] = ci;
    }

    // Extract the movie list, apply query + filter, then sort.
    var movies = items
        .where((ci) {
          if (ci.item.id == null) return false;
          if (query.isNotEmpty) {
            return ci.item.title!.toLowerCase().contains(query.toLowerCase());
          }
          return true;
        })
        .map((ci) => ci.item)
        .toList();

    movies = filter.filter(movies);
    movies = sorting.sort(movies, ascending);

    // Map sorted/filtered movies back to their consolidated wrappers.
    return movies
        .map((m) => lookup[m])
        .whereType<LunaConsolidatedItem<RadarrMovie>>()
        .toList();
  }

  Widget _movieList(
    List<LunaConsolidatedItem<RadarrMovie>> items,
    Map<String, List<RadarrQualityProfile>> profilesByInstance,
  ) {
    if (items.isEmpty) {
      return LunaMessage(
        text: 'radarr.NoMoviesFound'.tr(),
        buttonText: 'lunasea.Refresh'.tr(),
        onTap: _refreshKey.currentState!.show,
      );
    }

    final consolidated = context.watch<RadarrConsolidatedState>();
    final showInstanceLabel = consolidated.instances.length > 1;
    final registry = context.read<LunaModuleStateRegistry<RadarrState>>();

    return Selector<
      RadarrState,
      Tuple4<String, RadarrMoviesSorting, RadarrMoviesFilter, bool>
    >(
      selector: (_, state) => Tuple4(
        state.moviesSearchQuery,
        state.moviesSortType,
        state.moviesFilterType,
        state.moviesSortAscending,
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
            controller: RadarrNavigationBar.scrollControllers[0],
            children: [LunaMessage.inList(text: 'radarr.NoMoviesFound'.tr())],
          );
        }

        final itemExtent = showInstanceLabel
            ? _itemExtentWithLabel
            : RadarrCatalogueTile.itemExtent;

        return LunaListViewBuilder(
          controller: RadarrNavigationBar.scrollControllers[0],
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
            return ChangeNotifierProvider<RadarrState>.value(
              value: instanceState,
              child: RadarrCatalogueTile(
                movie: ci.item,
                profile: profile,
                instanceId: ci.instance.id,
                instanceLabel: showInstanceLabel
                    ? TextSpan(
                        text: ci.instance.displayName,
                        style: TextStyle(
                          color: LunaModule.RADARR.color.withValues(alpha: 0.8),
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
