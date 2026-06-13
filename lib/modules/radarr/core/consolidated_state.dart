import 'package:lunasea/database/models/service_instance.dart';
import 'package:lunasea/modules/radarr.dart';
import 'package:lunasea/system/consolidated/consolidated_item.dart';
import 'package:lunasea/system/state.dart';

/// Aggregated state for a consolidated Radarr view that merges data from
/// multiple enabled Radarr instances into unified futures.
class RadarrConsolidatedState extends LunaModuleState {
  final List<LunaServiceInstance> instances;
  final List<RadarrState> instanceStates;

  RadarrConsolidatedState({
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

  ////////////////
  /// MOVIES   ///
  ////////////////

  Future<List<LunaConsolidatedItem<RadarrMovie>>>? _movies;
  Future<List<LunaConsolidatedItem<RadarrMovie>>>? get movies => _movies;

  Future<List<LunaConsolidatedItem<RadarrMovie>>>? _upcoming;
  Future<List<LunaConsolidatedItem<RadarrMovie>>>? get upcoming => _upcoming;

  Future<List<LunaConsolidatedItem<RadarrMovie>>>? _missing;
  Future<List<LunaConsolidatedItem<RadarrMovie>>>? get missing => _missing;

  ///////////////////
  /// PROFILES    ///
  ///////////////////

  /// Quality profiles from all instances, keyed by [LunaServiceInstanceRef.key].
  Future<Map<String, List<RadarrQualityProfile>>>? _qualityProfilesByInstance;
  Future<Map<String, List<RadarrQualityProfile>>>?
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
        s.fetchMovies();
        s.fetchQualityProfiles();
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
    _movies = _mergeMovies();
    _upcoming = _mergeUpcoming();
    _missing = _mergeMissing();
    _qualityProfilesByInstance = _mergeQualityProfiles();
  }

  Future<List<LunaConsolidatedItem<RadarrMovie>>> _mergeMovies() async {
    final futures = instanceStates.map((s) => s.movies).toList();
    if (futures.any((f) => f == null)) return const [];
    final results = await Future.wait(futures.map((f) => f!));
    return [
      for (int i = 0; i < results.length; i++)
        for (final m in results[i])
          LunaConsolidatedItem(instance: instances[i], item: m),
    ];
  }

  Future<List<LunaConsolidatedItem<RadarrMovie>>> _mergeUpcoming() async {
    final futures = instanceStates.map((s) => s.upcoming).toList();
    if (futures.any((f) => f == null)) return const [];
    final results = await Future.wait(futures.map((f) => f!));
    return [
      for (int i = 0; i < results.length; i++)
        for (final m in results[i])
          LunaConsolidatedItem(instance: instances[i], item: m),
    ];
  }

  Future<List<LunaConsolidatedItem<RadarrMovie>>> _mergeMissing() async {
    final futures = instanceStates.map((s) => s.missing).toList();
    if (futures.any((f) => f == null)) return const [];
    final results = await Future.wait(futures.map((f) => f!));
    return [
      for (int i = 0; i < results.length; i++)
        for (final m in results[i])
          LunaConsolidatedItem(instance: instances[i], item: m),
    ];
  }

  Future<Map<String, List<RadarrQualityProfile>>>
  _mergeQualityProfiles() async {
    final futures = instanceStates.map((s) => s.qualityProfiles).toList();
    if (futures.any((f) => f == null)) return const {};
    final results = await Future.wait(futures.map((f) => f!));
    return {
      for (int i = 0; i < results.length; i++) instances[i].ref.key: results[i],
    };
  }
}
