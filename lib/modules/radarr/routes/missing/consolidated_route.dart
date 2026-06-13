import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';

/// Missing tab for the consolidated Radarr view.
///
/// Merges the missing/wanted lists from all enabled Radarr instances.
class RadarrConsolidatedMissingRoute extends StatefulWidget {
  const RadarrConsolidatedMissingRoute({super.key});

  @override
  State<RadarrConsolidatedMissingRoute> createState() => _State();
}

class _State extends State<RadarrConsolidatedMissingRoute>
    with AutomaticKeepAliveClientMixin {
  static final _itemExtentWithLabel = LunaBlock.calculateItemExtent(4);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  Future<List<Object>>? _mergedFuture;
  Future<List<LunaConsolidatedItem<RadarrMovie>>>? _missingFuture;
  Future<Map<String, List<RadarrQualityProfile>>>? _profilesFuture;

  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    final consolidated = context.read<RadarrConsolidatedState>();
    consolidated.fetchAll();
    if (consolidated.missing != null &&
        consolidated.qualityProfilesByInstance != null) {
      await Future.wait([
        consolidated.missing!,
        consolidated.qualityProfilesByInstance!,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LunaScaffold(scaffoldKey: _scaffoldKey, body: _body);
  }

  Widget get _body => LunaRefreshIndicator(
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
          selector: (_, s) => Tuple2(s.missing, s.qualityProfilesByInstance),
          builder: (context, tuple, _) {
            final future = _mergeFuture(tuple.item1, tuple.item2);
            if (future == null) return const LunaLoader();
            return FutureBuilder(
              future: future,
              builder: (context, AsyncSnapshot<List<Object>> snapshot) {
                if (snapshot.hasError) {
                  if (snapshot.connectionState != ConnectionState.waiting) {
                    LunaLogger().error(
                      'Unable to fetch consolidated Radarr missing',
                      snapshot.error,
                      snapshot.stackTrace,
                    );
                  }
                  return LunaMessage.error(
                    onTap: _refreshKey.currentState!.show,
                  );
                }
                if (snapshot.hasData) {
                  return _list(
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

  Future<List<Object>>? _mergeFuture(
    Future<List<LunaConsolidatedItem<RadarrMovie>>>? missing,
    Future<Map<String, List<RadarrQualityProfile>>>? profiles,
  ) {
    if (missing == null || profiles == null) return null;
    if (missing == _missingFuture && profiles == _profilesFuture) {
      return _mergedFuture;
    }
    _missingFuture = missing;
    _profilesFuture = profiles;
    return _mergedFuture = Future.wait([missing, profiles]);
  }

  Widget _list(
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

    final consolidated = context.read<RadarrConsolidatedState>();
    final showInstanceLabel = consolidated.instances.length > 1;
    final registry = context.read<LunaModuleStateRegistry<RadarrState>>();

    final itemExtent = showInstanceLabel
        ? _itemExtentWithLabel
        : RadarrMissingTile.itemExtent;

    return LunaListViewBuilder(
      controller: RadarrNavigationBar.scrollControllers[2],
      itemCount: items.length,
      itemExtent: itemExtent,
      itemBuilder: (context, index) {
        final ci = items[index];
        final instanceState = registry.get(ci.instance);
        final profiles = profilesByInstance[ci.instance.ref.key] ?? const [];
        final profile = profiles.firstWhereOrNull(
          (p) => p.id == ci.item.qualityProfileId,
        );
        return ChangeNotifierProvider<RadarrState>.value(
          value: instanceState,
          child: RadarrMissingTile(
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
  }
}
