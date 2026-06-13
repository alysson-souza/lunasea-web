import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';
import 'package:lunasea/system/state.dart';

/// Aggregated state for a consolidated Sonarr view that merges data from
/// multiple enabled Sonarr instances into unified futures.
class SonarrConsolidatedState extends LunaModuleState {
  final List<LunaServiceInstance> instances;
  final List<SonarrState> instanceStates;

  SonarrConsolidatedState({
    required this.instances,
    required this.instanceStates,
  }) : assert(instances.length == instanceStates.length) {
    for (final state in instanceStates) {
      state.addListener(_onInstanceStateChanged);
    }
    reset();
  }

  bool _refreshing = false;

  @override
  void dispose() {
    for (final state in instanceStates) {
      state.removeListener(_onInstanceStateChanged);
    }
    super.dispose();
  }

  @override
  void reset() {
    _refreshAll();
    notifyListeners();
  }

  //////////////
  /// SERIES ///
  //////////////

  Future<List<LunaConsolidatedItem<SonarrSeries>>>? _series;
  Future<List<LunaConsolidatedItem<SonarrSeries>>>? get series => _series;

  ////////////////
  /// UPCOMING ///
  ////////////////

  Future<List<LunaConsolidatedItem<SonarrCalendar>>>? _upcoming;
  Future<List<LunaConsolidatedItem<SonarrCalendar>>>? get upcoming => _upcoming;

  Future<List<LunaConsolidatedItem<SonarrMissingRecord>>>? _missing;
  Future<List<LunaConsolidatedItem<SonarrMissingRecord>>>? get missing =>
      _missing;

  ///////////////////
  /// PROFILES    ///
  ///////////////////

  Future<Map<String, List<SonarrQualityProfile>>>? _qualityProfilesByInstance;
  Future<Map<String, List<SonarrQualityProfile>>>?
  get qualityProfilesByInstance => _qualityProfilesByInstance;

  ////////////////
  /// REFRESH  ///
  ////////////////

  void fetchAll() {
    _refreshAll();
    notifyListeners();
  }

  void _refreshAll() {
    _refreshing = true;
    try {
      for (final s in instanceStates) {
        s.fetchAllSeries();
        s.fetchQualityProfiles();
        s.fetchUpcoming();
        s.fetchMissing();
      }
      _mergeInstanceFutures();
    } finally {
      _refreshing = false;
    }
  }

  void _onInstanceStateChanged() {
    if (_refreshing) return;
    _mergeInstanceFutures();
    notifyListeners();
  }

  void _mergeInstanceFutures() {
    _series = _mergeSeries();
    _upcoming = _mergeUpcoming();
    _missing = _mergeMissing();
    _qualityProfilesByInstance = _mergeQualityProfiles();
  }

  Future<List<LunaConsolidatedItem<SonarrSeries>>> _mergeSeries() async {
    final futures = instanceStates.map((s) => s.series).toList();
    if (futures.any((f) => f == null)) return const [];
    final results = await Future.wait(futures.map((f) => f!));
    return [
      for (int i = 0; i < results.length; i++)
        for (final entry in results[i].entries)
          LunaConsolidatedItem(instance: instances[i], item: entry.value),
    ];
  }

  Future<List<LunaConsolidatedItem<SonarrCalendar>>> _mergeUpcoming() async {
    final futures = instanceStates.map((s) => s.upcoming).toList();
    if (futures.any((f) => f == null)) return const [];
    final results = await Future.wait(futures.map((f) => f!));
    return [
      for (int i = 0; i < results.length; i++)
        for (final cal in results[i])
          LunaConsolidatedItem(instance: instances[i], item: cal),
    ];
  }

  Future<List<LunaConsolidatedItem<SonarrMissingRecord>>>
  _mergeMissing() async {
    final futures = instanceStates.map((s) => s.missing).toList();
    if (futures.any((f) => f == null)) return const [];
    final results = await Future.wait(futures.map((f) => f!));
    return [
      for (int i = 0; i < results.length; i++)
        for (final record
            in results[i].records ?? const <SonarrMissingRecord>[])
          LunaConsolidatedItem(instance: instances[i], item: record),
    ];
  }

  Future<Map<String, List<SonarrQualityProfile>>>
  _mergeQualityProfiles() async {
    final futures = instanceStates.map((s) => s.qualityProfiles).toList();
    if (futures.any((f) => f == null)) return const {};
    final results = await Future.wait(futures.map((f) => f!));
    return {
      for (int i = 0; i < results.length; i++) instances[i].ref.key: results[i],
    };
  }
}
